module Instana
  class SpanContext
    attr_accessor :trace_id
    attr_accessor :span_id
    attr_accessor :baggage

    # Create a new SpanContext
    #
    # @param tid [Integer] the trace ID
    # @param sid [Integer] the span ID
    # @param baggage [Hash] baggage applied to this trace
    #
    def initialize(tid, sid, baggage = nil)
      @trace_id = tid
      @span_id = sid
      @baggage = baggage
    end
  end
end
