require 'net/http'
require 'socket'
require 'sys/proctable'
require 'timers'
require 'uri'
require 'thread'

require 'instana/agent/helpers'
require 'instana/agent/hooks'
require 'instana/agent/tasks'

include Sys

module Instana
  OJ_OPTIONS = {:mode => :strict}

  class Agent
    include AgentHelpers
    include AgentHooks
    include AgentTasks

    attr_accessor :state
    attr_accessor :agent_uuid
    attr_accessor :process
    attr_accessor :collect_thread
    attr_accessor :thread_spawn_lock
    attr_accessor :extra_headers

    attr_accessor :testmode

    LOCALHOST = '127.0.0.1'.freeze
    MIME_JSON = 'application/json'.freeze
    DISCOVERY_PATH = 'com.instana.plugin.ruby.discovery'.freeze
    METRICS_PATH = "com.instana.plugin.ruby.%s"
    TRACES_PATH = "com.instana.plugin.ruby/traces.%s"

    def initialize
      @testmode = ENV.key?('INSTANA_TEST')

      # Supported two states (unannounced & announced)
      @state = :unannounced

      # Timestamp of the last successful response from
      # entity data reporting.
      @entity_last_seen = Time.now

      # Used to track the last time the collect timer was run.
      @last_collect_run = Time.now

      # Two timers, one for each state (unannounced & announced)
      @timers = ::Timers::Group.new
      @announce_timer = nil
      @pending_timer = nil
      @collect_timer = nil

      @thread_spawn_lock = Mutex.new

      # Detect platform flags
      @is_linux = (RbConfig::CONFIG['host_os'] =~ /linux/i) ? true : false
      @is_osx = (RUBY_PLATFORM =~ /darwin/i) ? true : false

      # In case we're running in Docker, have the default gateway available
      # to check in case we're running in bridged network mode
      if @is_linux && File.exist?("/sbin/ip")
        @default_gateway = `/sbin/ip route | awk '/default/ { print $3 }'`.chomp
      else
        @default_gateway = nil
      end

      # Re-useable HTTP client for communication with
      # the host agent.
      @httpclient = nil

      # Collect initial process info - repeat prior to announce
      # in `announce_sensor` in case of process rename, after fork etc.
      @process = ::Instana::Util.collect_process_info

      # The agent UUID returned from the host agent
      @agent_uuid = nil

      # This will hold info on the discovered agent host
      @discovered = nil

      # The agent may pass down custom headers for this sensor to capture
      @extra_headers = nil
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
      @thread_spawn_lock.synchronize {
        if @collect_thread && @collect_thread.alive?
          ::Instana.logger.info "[instana] Collect thread already started & alive.  Not spawning another."
        else
          @collect_thread = Thread.new do
            start
          end
        end
      }
    end

    # Sets up periodic timers and starts the agent in a background thread.
    #
    # There are three possible states for the agent:
    #   - :unannounced
    #   - :announced
    #   - :ready
    def setup
      if ENV.key?('INSTANA_DISABLE')
        ::Instana.logger.info "Instana gem disabled via environment variable (INSTANA_DISABLE).  Going to sit in a corner..."
      end

      # The announce timer
      # We attempt to announce this ruby sensor to the host agent.
      # In case of failure, we try again in 30 seconds.
      @announce_timer = @timers.now_and_every(30) do
        if @state == :unannounced && !ENV.key?('INSTANA_DISABLE')
          if host_agent_available? && announce_sensor
            transition_to(:announced)
            ::Instana.logger.debug "Announce successful.  Waiting on ready. (#{@state} pid:#{Process.pid} #{@process[:name]})"
          end
        end
      end

      # The pending timer
      # Handles the time between successful announce and when the host agent METRICS_PATH and TRACES_PATH
      # no longer return 404s and are truly ready to accept data.
      @pending_timer = @timers.now_and_every(1) do
        path = sprintf(METRICS_PATH, @process[:report_pid])
        uri = URI.parse("http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/#{path}")
        req = Net::HTTP::Post.new(uri)
        req.body = Oj.dump({}, OJ_OPTIONS)

        response = make_host_agent_request(req)
        if response && (response.code.to_i == 200)
          transition_to(:ready)
          ::Instana.logger.info "Host agent available. We're in business. (#{@state} pid:#{Process.pid} #{@process[:name]})"
        end
      end

      # The collect timer
      # If we are in announced state, send metric data (only delta reporting)
      # every ::Instana.config[:collector][:interval] seconds.
      @collect_timer = @timers.every(::Instana.config[:collector][:interval]) do
        # Make sure that this block doesn't get called more often than the interval.  This can
        # happen on high CPU load and a back up of timer runs.  If we are called before `interval`
        # then we just skip.
        unless (Time.now - @last_collect_run) < ::Instana.config[:collector][:interval]
          @last_collect_run = Time.now
          if @state == :ready
            if !::Instana.collector.collect_and_report
              # If report has been failing for more than 1 minute,
              # fall back to unannounced state
              if (Time.now - @entity_last_seen) > 60
                ::Instana.logger.warn "Host agent offline for >1 min.  Going to sit in a corner..."
                transition_to(:unannounced)
              end
            end
            ::Instana.processor.send
          end
        end
      end
    end

    # Starts the timer loop for the timers that were initialized
    # in the setup method.  This is blocking and should only be
    # called from an already initialized background thread.
    #
    def start
      if !ENV.key?('INSTANA_DISABLE') && !host_agent_available?
        if !ENV.key?("INSTANA_QUIET")
          ::Instana.logger.info "Instana host agent not available.  Will retry periodically. (Set env INSTANA_QUIET=1 to shut these messages off)"
        end
      end

      while true
        if @state == :unannounced
          @announce_timer.resume
          @pending_timer.pause
          @collect_timer.pause
        elsif @state == :announced
          @announce_timer.pause
          @pending_timer.resume
          @collect_timer.pause
        elsif @state == :ready
          @announce_timer.pause
          @pending_timer.pause
          @collect_timer.resume
        end
        @timers.wait
      end
    rescue Exception => e
      ::Instana.logger.warn { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      ::Instana.logger.debug { e.backtrace.join("\r\n") }
    ensure
      if @state == :ready
        # Pause the timers so they don't fire while we are reporting traces
        @announce_timer.pause
        @pending_timer.pause
        @collect_timer.pause

        ::Instana.logger.debug { "#{Thread.current}: Agent exiting. Reporting final spans (if any)." }
        ::Instana.processor.send
      end
    end

    # Collect process ID, name and arguments to notify
    # the host agent.
    #
    def announce_sensor
      unless @discovered
        ::Instana.logger.debug("#{__method__} called but discovery hasn't run yet!")
        return false
      end

      # Always re-collect process info before announce in case the process name has been
      # re-written (looking at you puma!)
      @process = ::Instana::Util.collect_process_info

      announce_payload = {}
      announce_payload[:name] = @process[:name]
      announce_payload[:args] = @process[:arguments]

      socket = nil
      if @is_linux && !@testmode
        # We create an open socket to the host agent in case we are running in a container
        # and the real pid needs to be detected.
        socket = TCPSocket.open @discovered[:agent_host], @discovered[:agent_port]

        announce_payload[:fd] = socket.fileno
        announce_payload[:inode] = File.readlink("/proc/self/fd/#{socket.fileno}")
        announce_payload[:cpuSetFileContent] = get_cpuset_contents

        sched_pid = get_sched_pid
        announce_payload[:pid] = sched_pid
        announce_payload[:pidFromParentNS] = running_in_container? && (sched_pid != Process.pid)
      else
        announce_payload[:pid] = Process.pid
        announce_payload[:pidFromParentNS] = true
      end

      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{DISCOVERY_PATH}")
      req = Net::HTTP::Put.new(uri)
      req.body = Oj.dump(announce_payload, OJ_OPTIONS)

      #::Instana.logger.debug("Announce payload: #{announce_payload}")
      #::Instana.logger.debug { "Announce: http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{DISCOVERY_PATH} - payload: #{req.body}" }

      response = make_host_agent_request(req, open_timeout=3, read_timeout=3, debug=true)

      if response && (response.code.to_i == 200)
        data = Oj.load(response.body, OJ_OPTIONS)
        @process[:report_pid] = data['pid']
        @agent_uuid = data['agentUuid']

        if data.key?('extraHeaders')
          @extra_headers = data['extraHeaders']
        end
        true
      else
        false
      end
    rescue => e
      Instana.logger.info { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      Instana.logger.debug { e.backtrace.join("\r\n") }
      return false
    ensure
      socket.close if socket && !socket.closed?
    end

    # Method to report metrics data to the host agent.
    #
    # @param paylod [Hash] The collection of metrics to report.
    #
    # @return [Boolean] true on success, false otherwise
    #
    def report_metrics(payload)
      if @state != :ready && !@testmode
        ::Instana.logger.debug "report_metrics called but agent not in ready state."
        return false
      end

      path = sprintf(METRICS_PATH, @process[:report_pid])
      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")
      req = Net::HTTP::Post.new(uri)

      req.body = Oj.dump(payload, OJ_OPTIONS)
      response = make_host_agent_request(req)

      if response
        if response.body && response.body.length > 2
          # The host agent returned something indicating that is has a request for us that we
          # need to process.
          handle_agent_tasks(response.body)
        end

        if response.code.to_i == 200
          @entity_last_seen = Time.now
          return true
        end

      end
      false
    rescue => e
      Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      Instana.logger.debug { e.backtrace.join("\r\n") }
    end

    # Accept and report spans to the host agent.
    #
    # @param spans [Array] An array of [Span]
    # @return [Boolean]
    #
    def report_spans(spans)
      if @state != :ready && !@testmode
        ::Instana.logger.debug "report_spans called but agent not in ready state."
        return false
      end

      ::Instana.logger.debug "Reporting #{spans.length} spans"

      path = sprintf(TRACES_PATH, @process[:report_pid])
      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")
      req = Net::HTTP::Post.new(uri)

      opts = OJ_OPTIONS.merge({omit_nil: true})

      req.body = Oj.dump(spans, opts)
      response = make_host_agent_request(req)

      if response
        last_trace_response = response.code.to_i

        if [200, 204].include?(last_trace_response)
          return true
        end
      end
      false
    rescue => e
      Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      Instana.logger.debug { e.backtrace.join("\r\n") }
    end

    # Check that the host agent is available and can be contacted.  This will
    # first check localhost and if not, then attempt on the default gateway
    # for docker in bridged mode.
    #
    def host_agent_available?
      @discovered ||= run_discovery

      if @discovered
        return true
      end
      false
    rescue => e
      Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      Instana.logger.debug { e.backtrace.join("\r\n") } unless @testmode
      return false
    end

    # Runs a discovery process to determine where we can contact the host agent.  This is usually just
    # localhost but in docker can be found on the default gateway. Another option is the INSTANA_AGENT_HOST
    # environment variable. This also allows for manual configuration via ::Instana.config[:agent_host/port].
    #
    # @return [Hash] a hash with :agent_host, :agent_port values or empty hash
    #
    def run_discovery
      discovered = {}

      ::Instana.logger.debug { "#{__method__}: Running agent discovery..." }

      # Try default location or manually configured (if so)
      uri = URI.parse("http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/")
      req = Net::HTTP::Get.new(uri)

      ::Instana.logger.debug { "#{__method__}: Trying #{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}" }

      response = make_host_agent_request(req)

      if response && (response.code.to_i == 200)
        discovered[:agent_host] = ::Instana.config[:agent_host]
        discovered[:agent_port] = ::Instana.config[:agent_port]
        ::Instana.logger.debug { "#{__method__}: Found #{discovered[:agent_host]}:#{discovered[:agent_port]}" }
        return discovered
      end

      return nil unless @is_linux

      # We are potentially running on Docker in bridged networking mode.
      # Attempt to contact default gateway
      uri = URI.parse("http://#{@default_gateway}:#{::Instana.config[:agent_port]}/")
      req = Net::HTTP::Get.new(uri)

      ::Instana.logger.debug { "#{__method__}: Trying default gateway #{@default_gateway}:#{::Instana.config[:agent_port]}" }

      response = make_host_agent_request(req)

      if response && (response.code.to_i == 200)
        discovered[:agent_host] = @default_gateway
        discovered[:agent_port] = ::Instana.config[:agent_port]
        ::Instana.logger.debug { "#{__method__}: Found #{discovered[:agent_host]}:#{discovered[:agent_port]}" }
        return discovered
      end

      nil
    end

    private

    # Handles any/all steps required in the transtion
    # between states.
    #
    # @param state [Symbol] Can be 1 of 2 possible states:
    #   `:announced`, `:unannounced`
    #
    def transition_to(state)
      ::Instana.logger.debug("Transitioning to #{state}")
      case state
      when :ready
        # announced
        @state = :ready

        # Reset the entity timer
        @entity_last_seen = Time.now
      when :announced
        # announce successful; set state
        @state = :announced

        # Reset the entity timer
        @entity_last_seen = Time.now
      when :unannounced
        @state = :unannounced
        # Reset our HTTP client
        @httpclient = nil
      else
        ::Instana.logger.debug "Uknown agent state: #{state}"
      end
      ::Instana.collector.reset_snapshot_timer!
      true
    end

    # Centralization of the net/http communications
    # with the host agent. Pass in a prepared <req>
    # of type Net::HTTP::Get|Put|Head
    #
    # @param req [Net::HTTP::Req] A prepared Net::HTTP request object of the type
    #  you wish to make (Get, Put, Post etc.)
    #
    def make_host_agent_request(req, open_timeout=1, read_timeout=1, debug=false)
      req['Accept'] = MIME_JSON
      req['Content-Type'] = MIME_JSON

      if @state == :unannounced
        @httpclient = Net::HTTP.new(req.uri.hostname, req.uri.port)
        @httpclient.open_timeout = open_timeout
        @httpclient.read_timeout = read_timeout
      end

      response = @httpclient.request(req)

      if debug
        ::Instana.logger.debug "#{req.method}->#{req.uri} body:(#{req.body}) Response:#{response} body:(#{response.body})"
      end

      response
    rescue Errno::ECONNREFUSED
      return nil
    rescue => e
      Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message} (to #{req.uri})" }
      return nil
    end
  end
end
