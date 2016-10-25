module Instana
  class Config
    @config = {}

    def initialize
      @config[:agent_host] = '127.0.0.1'
      @config[:agent_port] = 42699
      @config[:metrics] = {}
      @config[:metrics][:gc]     = { :enabled => true }
      @config[:metrics][:heap]   = { :enabled => false }
      @config[:metrics][:memory] = { :enabled => true }
      @config[:metrics][:thread] = { :enabled => true }
    end

    def self.[](key)
      @config[key.to_sym]
    end

    def self.[]=(key, value)
      @config[key.to_sym] = value
    end
  end
end
