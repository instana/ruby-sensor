# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  class LoggerDelegator < SimpleDelegator
    def initialize(obj)
      obj.level = level_from_environment
      super(obj)
    end

    private

    def level_from_environment
      # :nocov:
      return Logger::FATAL if ENV.key?('INSTANA_TEST') || ENV.key?('RACK_TEST')
      return Logger::DEBUG if ENV.key?('INSTANA_DEBUG')

      case ENV['INSTANA_LOG_LEVEL']
      when 'debug'
        Logger::DEBUG
      when 'warn'
        Logger::WARN
      when 'error'
        Logger::ERROR
      else
        Logger::INFO
      end
      # :nocov:
    end
  end
end
