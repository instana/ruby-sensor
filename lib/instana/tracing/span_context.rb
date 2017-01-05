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

    def trace_id_header
      ::Instana::Util.id_to_header(@trace_id)
    end

    def span_id_header
      ::Instana::Util.id_to_header(@span_id)
    end

    def to_hash
      { :trace_id => @trace_id, :span_id => @span_id }
    end
  end
end
