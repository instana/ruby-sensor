require 'net/http'
require 'uri'
require 'json'
require 'sys/proctable'
include Sys

module Instana
  class Agent
    attr_accessor :payload

    def initialize
      # Host agent defaults.  Can be configured via Instana.config
      @request_timeout = 5000
      @host = '127.0.0.1'
      @port = 42699
      @server_header = 'Instana Agent'

      # Snapshot data is collected once per process but resent
      # every 10 minutes along side process metrics.
      @snapshot = take_snapshot

      # The payload is the final resting place before being
      # sent off to the host agent
      @payload = {}

      # Set last snapshot to 10 minutes ago
      # so we send a snapshot on first report
      @last_snapshot = Time.now - 601
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
      data[:pid] = Process.pid
      data[:ruby_version] = RUBY_VERSION
      data[:versions] = {}

      process = ProcTable.ps(Process.pid)
      arguments = process.cmdline.split(' ')
      arguments.shift
      data[:exec_args] = arguments

      # Framework Detection
      if defined?(::RailsLts::VERSION)
        data[:framework] = "Rails on Rails LTS-#{::RailsLts::VERSION}"
        data[:appname] = Rails.application.class.parent_name

      elsif defined?(::Rails.version)
        data[:framework] = "Ruby on Rails #{::Rails.version}"
        data[:appname] = ::Rails.application.class.parent_name

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

      path = 'com.instana.plugin.ruby.discovery'
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Put.new(uri)

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = announce_payload.to_json

      ::Instana.logger.debug "Announcing sensor to #{path} for pid #{Process.pid}: #{announce_payload.to_json}"

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end
      Instana.logger.debug response.code
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # report_entity_data
    #
    # Method to report metrics data to the host agent.  Every 10 minutes, this
    # method will also send a process snapshot data.
    #
    def report_entity_data
      path = "com.instana.plugin.ruby.#{Process.pid}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)

      # Every 5 minutes, send snapshot data as well
      if (Time.now - @last_snapshot) > 600
        @payload.merge!(@snapshot)
        @last_snapshot = Time.now
      end

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = @payload.to_json

      Instana.logger.debug "Posting metrics to #{path}: #{@payload.to_json}"

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end

      # If snapshot data is in the payload and last response
      # was ok then delete the snapshot data.  Otherwise let it
      # ride for another run.
      if response.code.to_i == 200
        @snapshot.each do |k, v|
          @payload.delete(k)
        end
      end
      Instana.logger.debug response.code
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # host_agent_ready?
    #
    # Check that the host agent is available and can be contacted.
    #
    def host_agent_ready?
      uri = URI.parse("http://#{@host}:#{@port}/")
      req = Net::HTTP::Get.new(uri)

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'

      ::Instana.logger.debug "Checking agent availability...."

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end

      if response.code.to_i != 200
        Instana.logger.debug "Host agent returned #{response.code}"
        false
      else
        true
      end
    rescue Errno::ECONNREFUSED => e
      Instana.logger.debug "Agent not responding: #{e.inspect}"
      return false
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end
  end
end
