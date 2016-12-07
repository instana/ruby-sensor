require "logger"

module Instana
  class XLogger < Logger
    LEVELS = [:agent, :agent_comm, :trace].freeze
    STAMP = "Instana: ".freeze

    def initialize(*args)
      if ENV['INSTANA_GEM_DEV']
        self.debug_level=:agent
      end
      super(*args)
    end

    def debug_level=(levels)
      LEVELS.each do |l|
        instance_variable_set("@level_#{l}", false)
      end

      levels = [ levels ] unless levels.is_a?(Array)
      levels.each do |l|
        next unless LEVELS.include?(l)
        instance_variable_set("@level_#{l}", true)
      end
    end

    def agent(msg)
      return unless @level_agent
      self.debug(msg)
    end

    def agent_comm(msg)
      return unless @level_agent_comm
      self.debug(msg)
    end

    def trace(msg)
      return unless @level_trace
      self.debug(msg)
    end

    def error(msg)
      super(STAMP + msg)
    end

    def warn(msg)
      super(STAMP + msg)
    end

    def info(msg)
      super(STAMP + msg)
    end

    def debug(msg)
      super(STAMP + msg)
    end

    def unkown(msg)
      super(STAMP + msg)
    end
  end
end

