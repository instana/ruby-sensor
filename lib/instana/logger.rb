require "logger"

module Instana
  class XLogger < Logger
    LEVELS = [:agent, :agent_comm, :trace, :agent_response].freeze
    STAMP = "Instana: ".freeze

    def initialize(*args)
      if ENV.key?('INSTANA_GEM_TEST')
        self.level = Logger::DEBUG
      elsif ENV.key?('INSTANA_GEM_DEV')
        self.level = Logger::DEBUG
        self.debub_level = nil
      else
        self.level = Logger::WARN
      end
      super(*args)
    end

    # Sets the debug level for this logger.  The debug level is broken up into various
    # sub-levels as defined in LEVELS:
    #
    # :agent          - All agent related messages such as state & announcements
    # :agent_comm     - Output all payload comm sent between this Ruby gem and the host agent
    # :trace          - Output all traces reported to the host agent
    # :agent_response - Outputs messages related to handling requests received by the host agent
    #
    # To use:
    # ::Instana.logger.debug_level = [:agent_comm, :trace]
    #
    def debug_level=(levels)
      return unless levels

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

    def agent_response(msg)
      return unless @level_agent_response
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

