# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module OpenTracing
  class << self
    # Text format for #inject and #extract
    FORMAT_TEXT_MAP = 1

    # Binary format for #inject and #extract
    FORMAT_BINARY = 2

    # Ruby Specific format to handle how Rack changes environment variables.
    FORMAT_RACK = 3

    attr_accessor :global_tracer

    def method_missing(method_name, *args, &block)
      @global_tracer.send(method_name, *args, &block)
    end
  end
end
