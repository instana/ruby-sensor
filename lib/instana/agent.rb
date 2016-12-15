require 'net/http'
require 'uri'
require 'json'
require 'timers'
require 'sys/proctable'
include Sys

module Instana
  class Agent
    attr_accessor :state
    attr_accessor :agent_uuid

    LOCALHOST = '127.0.0.1'.freeze
    MIME_JSON = 'application/json'.freeze
    DISCOVERY_PATH = 'com.instana.plugin.ruby.discovery'.freeze

    def initialize
      # Host agent defaults.  Can be configured via Instana.config
      @host = LOCALHOST
      @port = 42699

      # Supported two states (unannounced & announced)
      @state = :unannounced

      # Store the pid from process boot so we can detect forks
      @pid = Process.pid

      # Snapshot data is collected once per process but resent
      # every 10 minutes along side process metrics.
      @snapshot = ::Instana::Util.take_snapshot

      # Set last snapshot to just under 10 minutes ago
      # so we send a snapshot sooner than later
      @last_snapshot = Time.now - 570

      # Timestamp of the last successful response from
      # entity data reporting.
      @entity_last_seen = Time.now

      # Two timers, one for each state (unannounced & announced)
      @timers = ::Timers::Group.new
      @announce_timer = nil
      @collect_timer = nil

      # Detect platform flags
      @is_linux = (RUBY_PLATFORM =~ /linux/i) ? true : false
      @is_osx = (RUBY_PLATFORM =~ /darwin/i) ? true : false

      # In case we're running in Docker, have the default gateway available
      # to check in case we're running in bridged network mode
      if @is_linux
        @default_gateway = `/sbin/ip route | awk '/default/ { print $3 }'`.chomp
      else
        @default_gateway = nil
      end

      # The agent UUID returned from the host agent
      @agent_uuid = nil

      collect_process_info
    end

    # Used in class initialization and after a fork, this method
    # collects up process information and stores it in @process
    #
    def collect_process_info
      @process = {}
      cmdline = ProcTable.ps(Process.pid).cmdline.split("\0")
      @process[:name] = cmdline.shift
      @process[:arguments] = cmdline

      if @is_osx
        # Handle OSX bug where env vars show up at the end of process name
        # such as MANPATH etc..
        @process[:name].gsub!(/[_A-Z]+=\S+/, '')
        @process[:name].rstrip!
      end

      @process[:original_pid] = @pid
      # This is usually Process.pid but in the case of docker, the host agent
      # will return to us the true host pid in which we use to report data.
      @process[:report_pid] = nil
    end

    # Used post fork to re-initialize state and restart communications with
    # the host agent.
    #
    def after_fork
      ::Instana.logger.agent "after_fork hook called. Falling back to unannounced state and spawning a new background agent thread."

      # Re-collect process information post fork
      @pid = Process.pid
      collect_process_info

      transition_to(:unannounced)
      setup
      spawn_background_thread
    end

    # Spawns the background thread and calls start.  This method is separated
    # out for those who wish to control which thread the background agent will
    # run in.
    #
    # This method can be overridden with the following:
    #
    # module Instana
    #   class Agent
    #     def spawn_background_thread
    #       # start thread
    #       start
    #     end
    #   end
    # end
    #
    def spawn_background_thread
      # The thread calling fork is the only thread in the created child process.
      # fork doesn’t copy other threads.
      # Restart our background thread
      Thread.new do
        start
      end
    end

    # Sets up periodic timers and starts the agent in a background thread.
    #
    def setup
      # The announce timer
      # We attempt to announce this ruby sensor to the host agent.
      # In case of failure, we try again in 30 seconds.
      @announce_timer = @timers.now_and_every(30) do
        if host_agent_ready? && announce_sensor
          ::Instana.logger.debug "Announce successful. Switching to metrics collection."
          transition_to(:announced)
        end
      end

      # The collect timer
      # If we are in announced state, send metric data (only delta reporting)
      # every ::Instana::Collector.interval seconds.
      @collect_timer = @timers.every(::Instana::Collector.interval) do
        if @state == :announced
          if !::Instana::Collector.collect_and_report
            # If report has been failing for more than 1 minute,
            # fall back to unannounced state
            if (Time.now - @entity_last_seen) > 60
              ::Instana.logger.debug "Metrics reporting failed for >1 min.  Falling back to unannounced state."
              transition_to(:unannounced)
            end
          end
          ::Instana.processor.send
        end
      end
    end

    # Starts the timer loop for the timers that were initialized
    # in the setup method.  This is blocking and should only be
    # called from an already initialized background thread.
    #
    def start
      ::Instana.logger.warn "Host agent not available.  Will retry periodically." unless host_agent_ready?
      loop do
        if @state == :unannounced
          @collect_timer.pause
          @announce_timer.resume
        else
          @announce_timer.pause
          @collect_timer.resume
        end
        @timers.wait
      end
    ensure
      if @state == :announced
        # Pause the timers so they don't fire while we are
        # reporting traces
        @collect_timer.pause
        @announce_timer.pause

        ::Instana.logger.debug "Agent exiting. Reporting final #{::Instana.processor.queue_count} trace(s)."
        ::Instana.processor.send
      end
    end

    # Collect process ID, name and arguments to notify
    # the host agent.
    #
    def announce_sensor
      announce_payload = {}
      announce_payload[:pid] = pid_namespace? ? get_real_pid : Process.pid
      announce_payload[:args] = @process[:arguments]

      uri = URI.parse("http://#{@host}:#{@port}/#{DISCOVERY_PATH}")
      req = Net::HTTP::Put.new(uri)
      req.body = announce_payload.to_json

      ::Instana.logger.agent "Announce: http://#{@host}:#{@port}/#{DISCOVERY_PATH} - payload: #{req.body}"

      response = make_host_agent_request(req)

      if response && (response.code.to_i == 200)
        data = JSON.parse(response.body)
        @process[:report_pid] = data['pid']
        @agent_uuid = data['agentUuid']
        true
      else
        false
      end
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end

    # Method to report metrics data to the host agent.
    #
    # @param paylod [Hash] The collection of metrics to report.
    #
    def report_entity_data(payload)
      with_snapshot = false
      path = "com.instana.plugin.ruby.#{@process[:report_pid]}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)

      # Every 5 minutes, send snapshot data as well
      if (Time.now - @last_snapshot) > 600
        with_snapshot = true
        payload.merge!(@snapshot)

        # Add in process related that could have changed since
        # snapshot was taken.
        p = { :pid => @process[:report_pid] }
        p[:name] = @process[:name]
        p[:exec_args] = @process[:arguments]
        payload.merge!(p)
      end

      req.body = payload.to_json
      response = make_host_agent_request(req)

      if response
        if response.body.length > 2
          # The host agent returned something indicating that is has a request for us that we
          # need to process.
          handle_response(response.body)
        end

        if response.code.to_i == 200
          @entity_last_seen = Time.now
          @last_snapshot = Time.now if with_snapshot
          return true
        end

      end
      false
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # When a request is received by the host agent, it is sent here
    # from processing and response.
    #
    # @param json_string [String] the request from the host agent
    #
    def handle_response(json_string)
      their_request = JSON.parse(json_string).first

      if their_request.key?("action")
        if their_request["action"] == "ruby.source"
          payload = ::Instana::Util.get_rb_source(their_request["args"]["file"])
        else
          payload = { :error => "Unrecognized action: #{their_request["action"]}. An newer Instana gem may be required for this. Current version: #{::Instana::VERSION}" }
        end
      else
        payload = { :error => "Instana Ruby: No action specified in request." }
      end

      path = "com.instana.plugin.ruby/response.#{@process[:report_pid]}?messageId=#{URI.encode(their_request['messageId'])}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)
      req.body = payload.to_json
      ::Instana.logger.agent_response "Responding to agent: #{req.inspect}"
      make_host_agent_request(req)
    end

    # Accept and report spans to the host agent.
    #
    # @param traces [Array] An array of [Span]
    # @return [Boolean]
    #
    def report_spans(spans)
      return unless @state == :announced

      path = "com.instana.plugin.ruby/traces.#{@process[:report_pid]}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)

      req.body = spans.to_json
      response = make_host_agent_request(req)

      if response
        last_trace_response = response.code.to_i

        if [200, 204].include?(last_trace_response)
          return true
        end
      end
      false
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # Check that the host agent is available and can be contacted.  This will
    # first check localhost and if not, then attempt on the default gateway
    # for docker in bridged mode.  It will save where it found the host agent
    # in @host that is used in subsequent HTTP calls.
    #
    def host_agent_ready?
      # Localhost
      uri = URI.parse("http://#{LOCALHOST}:#{@port}/")
      req = Net::HTTP::Get.new(uri)

      response = make_host_agent_request(req)

      if response && (response.code.to_i == 200)
        @host = LOCALHOST
        return true
      end

      return false unless @is_linux

      # We are potentially running on Docker in bridged networking mode.
      # Attempt to contact default gateway
      uri = URI.parse("http://#{@default_gateway}:#{@port}/")
      req = Net::HTTP::Get.new(uri)

      response = make_host_agent_request(req)

      if response && (response.code.to_i == 200)
        @host = @default_gateway
        return true
      end
      false
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end

    # Returns the PID that we are reporting to
    #
    def report_pid
      @process[:report_pid]
    end

    # Indicates if the agent is ready to send metrics
    # and/or data.
    #
    def ready?
      # In test, we're always ready :-)
      return true if ENV['INSTANA_GEM_TEST']

      if forked?
        ::Instana.logger.agent "Instana: detected fork.  Calling after_fork"
        after_fork
      end

      @state == :announced
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end

    private

    # Handles any/all steps required in the transtion
    # between states.
    #
    # @param state [Symbol] Can be 1 of 2 possible states:
    #   `:announced`, `:unannounced`
    #
    def transition_to(state)
      ::Instana.logger.agent("Transitioning to #{state}")
      case state
      when :announced
        # announce successful; set state
        @state = :announced

        # Reset the entity timer
        @entity_last_seen = Time.now

        # Set last snapshot to 10 minutes ago
        # so we send a snapshot on first report
        @last_snapshot = Time.now - 601
      when :unannounced
        @state = :unannounced

        # Set last snapshot to 10 minutes ago
        # so we send a snapshot on first report
        @last_snapshot = Time.now - 601
      else
        ::Instana.logger.warn "Uknown agent state: #{state}"
      end
    end

    # Centralization of the net/http communications
    # with the host agent. Pass in a prepared <req>
    # of type Net::HTTP::Get|Put|Head
    #
    # @param req [Net::HTTP::Req] A prepared Net::HTTP request object of the type
    #  you wish to make (Get, Put, Post etc.)
    #
    def make_host_agent_request(req)
      req['Accept'] = MIME_JSON
      req['Content-Type'] = MIME_JSON

      response = nil
      Net::HTTP.start(req.uri.hostname, req.uri.port, :open_timeout => 1, :read_timeout => 1) do |http|
        response = http.request(req)
      end
      ::Instana.logger.agent_comm "#{req.method}->#{req.uri} body:(#{req.body}) Response:#{response} body:(#{response.body})"
      response
    rescue Errno::ECONNREFUSED
      return nil
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return nil
    end

    # Indicates whether we are running in a pid namespace (such as
    # Docker).
    #
    def pid_namespace?
      return false unless @is_linux
      Process.pid != get_real_pid
    end

    # Attempts to determine the true process ID by querying the
    # /proc/<pid>/sched file.  This works on linux currently.
    #
    def get_real_pid
      raise RuntimeError.new("Unsupported platform: get_real_pid") unless @is_linux
      v = File.open("/proc/#{Process.pid}/sched", &:readline)
      v.match(/\d+/).to_s.to_i
    end

    # Determine whether the pid has changed since Agent start.
    #
    # @ return [Boolean] true or false to indicate if forked
    #
    def forked?
      @pid != Process.pid
    end
  end
end
