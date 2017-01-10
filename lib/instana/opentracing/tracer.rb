module OpenTracing
  class << self
    # Text format for #inject and #extract
    FORMAT_TEXT_MAP = 1

    # Binary format for #inject and #extract
    FORMAT_BINARY = 2

    # Ruby Specific format to handle how Rack changes environment variables.
    FORMAT_RACK = 3

    attr_accessor :global_tracer
  end
end
