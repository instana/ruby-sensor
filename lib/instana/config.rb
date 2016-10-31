module Instana
  class Config

    def initialize
      @config = {}
      @config[:agent_host] = '127.0.0.1'
      @config[:agent_port] = 42699
      @config[:metrics] = {}
      @config[:metrics][:gc]     = { :enabled => true }
      @config[:metrics][:heap]   = { :enabled => false }
      @config[:metrics][:memory] = { :enabled => true }
      @config[:metrics][:thread] = { :enabled => true }
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
