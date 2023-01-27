# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require "instana/open_tracing/carrier"
require "instana/open_tracing/instana_tracer"

module OpenTracing
  class << self
    # Text format for #inject and #extract
    FORMAT_TEXT_MAP = 1

    # Binary format for #inject and #extract
    FORMAT_BINARY = 2

    # Ruby Specific format to handle how Rack changes environment variables.
    FORMAT_RACK = 3

    attr_accessor :global_tracer

    def method_missing(method_name, *args, **kwargs, &block)
      @global_tracer.send(method_name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, all)
      @global_tracer.respond_to?(name, all)
    end
  end
end

# Set the global tracer to our OT tracer
# which supports the OT specification
OpenTracing.global_tracer = OpenTracing::InstanaTracer.new(::Instana.tracer)
