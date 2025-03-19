# (c) Copyright IBM Corp. 2025

module Instana
  # The Trace API allows recording a set of events, triggered as a result of a
  # single logical operation, consolidated across various components of an
  # application.
  module Trace
    include OpenTelemetry::Trace

    module_function

    ID_RANGE = -2**63..2**63 - 1

    # Generates a valid trace identifier

    def generate_trace_id(size = 1)
      Array.new(size) { rand(ID_RANGE) }
           .pack('q>*')
           .unpack1('H*')
    end

    # Generates a valid span identifier
    #
    def generate_span_id(size = 1)
      Array.new(size) { rand(ID_RANGE) }
           .pack('q>*')
           .unpack1('H*')
    end
  end
end

require 'instana/trace/span_context'
require 'instana/trace/span_kind'
require 'instana/trace/span'
require 'instana/trace/tracer'
