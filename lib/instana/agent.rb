require 'net/http'
require 'uri'
require 'json'
require 'timers'
require 'sys/proctable'
include Sys

module Instana
  class Agent
    attr_accessor :state

    LOCALHOST = '127.0.0.1'.freeze
    MIME_JSON = 'application/json'.freeze
    DISCOVERY_PATH = 'com.instana.plugin.ruby.discovery'.freeze

    def initialize
      # Host agent defaults.  Can be configured via Instana.config
      @host = LOCALHOST
      @port = 42699

      # Supported two states (unannounced & announced)
      @state = :unannounced

      # Snapshot data is collected once per process but resent
      # every 10 minutes along side process metrics.
      @snapshot = take_snapshot

      # Set last snapshot to 10 minutes ago
      # so we send a snapshot on first report
      @last_snapshot = Time.now - 601

      # Timestamp of the last successful response from
      # entity data reporting.
      @entity_last_seen = Time.now

      # Two timers, one for each state (unannounced & announced)
      @timers = ::Timers::Group.new
      @announce_timer = nil
      @collect_timer = nil

      # Detect if we're on linux or not (used in host_agent_ready?)
      @is_linux = (RUBY_PLATFORM =~ /linux/i) ? true : false

      # In case we're running in Docker, have the default gateway available
      # to check in case we're running in bridged network mode
      @default_gateway = `/sbin/ip route | awk '/default/ { print $3 }'`.chomp
    end

    ##
    # start
    #
    #
    def start
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
          unless ::Instana::Collector.collect_and_report
            # If report has been failing for more than 1 minute,
            # fall back to unannounced state
            if (Time.now - @entity_last_seen) > 60
              ::Instana.logger.debug "Metrics reporting failed for >1 min.  Falling back to unannounced state."
              transition_to(:unannounced)
            end
          end
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

    ##
    # announce_sensor
    #
    # Collect process ID, name and arguments to notify
    # the host agent.
    #
    def announce_sensor
      process = ProcTable.ps(Process.pid)
      announce_payload = {}
      announce_payload[:pid] = Process.pid

      arguments = process.cmdline.split(' ')
      arguments.shift
      announce_payload[:args] = arguments

      uri = URI.parse("http://#{@host}:#{@port}/#{DISCOVERY_PATH}")
      req = Net::HTTP::Put.new(uri)
      req.body = announce_payload.to_json

      response = make_host_agent_request(req)
      response && (response.code.to_i == 200) ? true : false
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # report_entity_data
    #
    # Method to report metrics data to the host agent.
    #
    def report_entity_data(payload)
      with_snapshot = false
      path = "com.instana.plugin.ruby.#{Process.pid}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)

      # Every 5 minutes, send snapshot data as well
      if (Time.now - @last_snapshot) > 600
        with_snapshot = true
        payload.merge!(@snapshot)
      end

      req.body = payload.to_json
      response = make_host_agent_request(req)

      if response
        last_entity_response = response.code.to_i

        if last_entity_response == 200
          @entity_last_seen = Time.now
          @last_snapshot = Time.now if with_snapshot

          #::Instana.logger.debug "entity response #{last_entity_response}: #{payload.to_json}"
          return true
        end
        #::Instana.logger.debug "entity response #{last_entity_response}: #{payload.to_json}"
      end
      false
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # host_agent_ready?
    #
    # Check that the host agent is available and can be contacted.  This will
    # first check localhost and if not, then attempt on the default gateway
    # for docker in bridged mode.
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
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end

    private

    ##
    # transition_to
    #
    # Handles any/all steps required in the transtion
    # between states.
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

    ##
    # make host_agent_request
    #
    # Centralization of the net/http communications
    # with the host agent. Pass in a prepared <req>
    # of type Net::HTTP::Get|Put|Head
    #
    def make_host_agent_request(req)
      req[:Accept] = MIME_JSON
      req[:'Content-Type'] = MIME_JSON

      response = nil
      Net::HTTP.start(req.uri.hostname, req.uri.port, :open_timeout => 1, :read_timeout => 1) do |http|
        response = http.request(req)
      end
      response
    rescue Errno::ECONNREFUSED => e
      Instana.logger.debug "Agent not responding. Connection refused."
      return nil
    rescue => e
      Instana.logger.debug "Host agent request error: #{e.inspect}"
      return nil
    end

    ##
    # take_snapshot
    #
    # Method to collect up process info for snapshots.  This
    # is generally used once per process.
    #
    def take_snapshot
      data = {}

      data[:sensorVersion] = ::Instana::VERSION
      data[:pid] = ::Process.pid
      data[:ruby_version] = RUBY_VERSION

      process = ::ProcTable.ps(Process.pid)
      arguments = process.cmdline.split(' ')
      data[:name] = arguments.shift
      data[:exec_args] = arguments

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
      ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ::Instana.logger.debug e.backtrace.join("\r\n")
      return data
    end
  end
end
