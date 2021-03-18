# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "logger"
require "instana/version"
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collector
    attr_accessor :tracer
    attr_accessor :processor
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :pid
    attr_reader :secrets

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @agent  = ::Instana::Agent.new
      @tracer = ::Instana::Tracer.new
      @processor = ::Instana::Processor.new
      @collector = ::Instana::Collector.new
      @secrets = ::Instana::Secrets.new
    end
  end
end

# Setup the logger as early as possible

# Default Logger outputs to STDOUT
::Instana.logger = Logger.new(STDOUT)

# Can instead log to a file that is rotated every 10M
# ::Instana.logger = Logger.new("instana.log", 10, 1073741824)

if ENV.key?('INSTANA_GEM_TEST')
  ::Instana.logger.level = Logger::DEBUG
elsif ENV.key?('INSTANA_GEM_DEV') || ENV.key?('INSTANA_DEBUG')
  ::Instana.logger.level = Logger::DEBUG
elsif ENV.key?('INSTANA_QUIET')
  ::Instana.logger.level = Logger::FATAL
else
  ::Instana.logger.level = Logger::WARN
end

::Instana.logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime}: #{severity.rjust(5)} Instana: #{progname} #{msg}\n"
end


::Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation version #{::Instana::VERSION}"
