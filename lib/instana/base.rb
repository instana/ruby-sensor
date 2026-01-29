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
    attr_reader :serverless
    attr_accessor :tracer_provider

    ##
    # span_filtering_config
    #
    # Returns the span filtering configuration instance
    #
    def span_filtering_config
      ::Instana::SpanFiltering.configuration
    end

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @agent = ::Instana::Backend::Agent.new
      @tracer_provider = ::Instana::Trace::TracerProvider.new
      @tracer = @tracer_provider.tracer('instana_tracer')
      @processor = ::Instana::Processor.new
      @secrets = ::Instana::Secrets.new
      @serverless = ::Instana::Serverless.new
    end

    def logger
      @logger ||= ::Instana::LoggerDelegator.new(Logger.new(STDOUT))
    end

    def logger=(val)
      @logger.__setobj__(val)
    end
  end
end
