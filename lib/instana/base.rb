# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "logger"
require "instana/version"
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :tracer
    attr_accessor :processor
    attr_accessor :config
    attr_accessor :pid
    attr_reader :secrets

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @agent  = ::Instana::Backend::Agent.new
      @tracer = ::Instana::Tracer.new
      @processor = ::Instana::Processor.new
      @secrets = ::Instana::Secrets.new
    end

    def logger
      @logger ||= ::Instana::LoggerDelegator.new(Logger.new(STDOUT))
    end

    def logger=(val)
      @logger.__setobj__(val)
    end
  end
end

::Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation version #{::Instana::VERSION}"
