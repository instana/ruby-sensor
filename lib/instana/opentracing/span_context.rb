module Instana
  class SpanContext < ::OpenTracing::SpanContext
    # Create a new SpanContext
    #
    # @param id the ID of the Context
    # @param trace_id the ID of the current trace
    # @param baggage baggage
    def initialize(baggage = {})
      @trace_id = nil
      @span_id = nil
      @baggage = baggage
    end
  end
end
