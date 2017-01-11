module Instana
  class Config

    def initialize
      @config = {}
      @config[:agent_host] = '127.0.0.1'
      @config[:agent_port] = 42699
      @config[:metrics] = {}
      @config[:metrics][:gc]     = { :enabled => true }
      @config[:metrics][:memory] = { :enabled => true }
      @config[:metrics][:thread] = { :enabled => true }

      # EUM Related
      @config[:eum_api_key] = nil
      @config[:eum_baggage] = {}

      # HTTP Clients
      @config[:excon]         = { :enabled => true }
      @config[:nethttp]       = { :enabled => true }
      @config[:'rest-client'] = { :enabled => true }
    end

    def [](key)
      @config[key.to_sym]
    end

    def []=(key, value)
      @config[key.to_sym] = value
    end
  end
end

::Instana.config = ::Instana::Config.new
