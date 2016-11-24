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
      @snapshot = take_snapshot

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

    # Determine whether the pid has changed since Agent start.
    #
    # @ return [Boolean] true or false to indicate if forked
    #
    def forked?
      @pid != Process.pid
    end

    # Used post fork to re-initialize state and restart communications with
    # the host agent.
    #
    def after_fork
      ::Instana.logger.debug "after_fork hook called. Falling back to unannounced state."

      # Re-collect process information post fork
      @pid = Process.pid
      collect_process_info

      # Set last snapshot to 10 minutes ago
      # so we send a snapshot sooner than later
      @last_snapshot = Time.now - 600

      transition_to(:unannounced)
      start
    end

    # Sets up periodic timers and starts the agent in a background thread.
    #
    def start
      # The announce timer
      # We attempt to announce this ruby sensor to the host agent.
      # In case of failure, we try again in 30 seconds.
      @announce_timer = @timers.now_and_every(30) do
        if forked?
          after_fork
          break
        end
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
          if forked?
            after_fork
            break
          end
          unless ::Instana::Collector.collect_and_report
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

      # Start the background ruby sensor thread.  It works off of timers and
      # is sleeping otherwise
      Thread.new do
        loop {
          if @state == :unannounced
            @collect_timer.pause
            @announce_timer.resume
          else
            @announce_timer.pause
            @collect_timer.resume
          end
          @timers.wait
        }
      end
    end

    # Indicates if the agent is ready to send metrics
    # or data.
    #
    def ready?
      # In test, we're always ready :-)
      return true if ENV['INSTANA_GEM_TEST']

      @state == :announced
    end

    # Returns the PID that we are reporting to
    #
    def report_pid
      @process[:report_pid]
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

      # ::Instana.logger.debug "Announce: http://#{@host}:#{@port}/#{DISCOVERY_PATH} - payload: #{req.body}"

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
        last_entity_response = response.code.to_i

        #::Instana.logger.debug "entity http://#{@host}:#{@port}/#{path}: response=#{last_entity_response}: #{payload.to_json}"

        if last_entity_response == 200
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

        #::Instana.logger.debug "traces response #{last_trace_response}: #{spans.to_json}"

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

    private

    # Handles any/all steps required in the transtion
    # between states.
    #
    # @param state [Symbol] Can be 1 of 2 possible states:
    #   `:announced`, `:unannounced`
    #
    def transition_to(state)
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
      response
    rescue Errno::ECONNREFUSED => e
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

    # Method to collect up process info for snapshots.  This
    # is generally used once per process.
    #
    def take_snapshot
      data = {}

      data[:sensorVersion] = ::Instana::VERSION
      data[:ruby_version] = RUBY_VERSION

      # Since a snapshot is only taken on process boot,
      # this is ok here.
      data[:start_time] = Time.now.to_s

      # Framework Detection
      if defined?(::RailsLts::VERSION)
        data[:framework] = "Rails on Rails LTS-#{::RailsLts::VERSION}"

      elsif defined?(::Rails.version)
        data[:framework] = "Ruby on Rails #{::Rails.version}"

      elsif defined?(::Grape::VERSION)
        data[:framework] = "Grape #{::Grape::VERSION}"

      elsif defined?(::Padrino::VERSION)
        data[:framework] = "Padrino #{::Padrino::VERSION}"

      elsif defined?(::Sinatra::VERSION)
        data[:framework] = "Sinatra #{::Sinatra::VERSION}"
      end

      data
    rescue => e
      ::Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ::Instana.logger.debug e.backtrace.join("\r\n")
      return data
    end
  end
end
