# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  class SpanContext
    attr_accessor :trace_id
    attr_accessor :span_id
    attr_accessor :baggage

    # Create a new SpanContext
    #
    # @param tid [Integer] the trace ID
    # @param sid [Integer] the span ID
    # @param level [Integer] default 1
    # @param baggage [Hash] baggage applied to this trace
    #
    def initialize(tid, sid, level = 1, baggage = {})
      @trace_id = tid
      @span_id = sid
      @level = level
      @baggage = baggage || {}
    end

    def trace_id_header
      ::Instana::Util.id_to_header(@trace_id)
    end

    def span_id_header
      ::Instana::Util.id_to_header(@span_id)
    end

    def trace_parent_header
      return '' unless valid?

      trace = (@baggage[:external_trace_id] || trace_id_header).rjust(32, '0')
      parent = span_id_header.rjust(16, '0')
      flags = @level == 1 ? "01" : "00"

      "00-#{trace}-#{parent}-#{flags}"
    end

    def trace_state_header
      return '' unless valid?

      external_state = @baggage[:external_state] || ''
      state = external_state.split(/,/)

      if @level == 1
        state = state.reject { |s| s.start_with?('in=') }
        state.unshift("in=#{trace_id_header};#{span_id_header}")
      end

      state.compact.join(',')
    end

    def to_hash
      { :trace_id => @trace_id, :span_id => @span_id }
    end

    def valid?
      @baggage && @trace_id
    end
  end
end
