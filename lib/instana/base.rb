require "instana/version"
require 'instana/logger'
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collectors
    attr_accessor :tracer
    attr_accessor :processor
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :pid

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @logger = ::Instana::XLogger.new(STDOUT)
      @logger.unknown "Stan is on the scene.  Starting Instana instrumentation."

      @agent  = ::Instana::Agent.new
      @tracer = ::Instana::Tracer.new
      @processor = ::Instana::Processor.new
      @collectors = []
    end

    # Indicates whether we are running in a development environment.
    #
    # @return Boolean
    #
    def debug?
      ENV.key?('INSTANA_GEM_DEV')
    end

    # Indicates whether we are running in the test environment.
    #
    # @return Boolean
    #
    def test?
      ENV.key?('INSTANA_GEM_TEST')
    end
  end
end
