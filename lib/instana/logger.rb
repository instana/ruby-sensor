require "logger"

module Instana
  class XLogger < Logger
    STAMP = "Instana: ".freeze

    def initialize(*args)
      super(*args)
      if ENV.key?('INSTANA_GEM_TEST')
        self.level = Logger::DEBUG
      elsif ENV.key?('INSTANA_GEM_DEV')
        self.level = Logger::DEBUG
      elsif ENV.key?('INSTANA_QUIET')
        self.level = Logger::FATAL
      else
        self.level = Logger::WARN
      end
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
