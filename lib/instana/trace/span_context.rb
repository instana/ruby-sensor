# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  class SpanContext < OpenTelemetry::Trace::SpanContext
    attr_accessor :trace_id, :span_id, :baggage
    attr_reader :level

    # Create a new SpanContext
    #
    # @param tid [Integer] the trace ID
    # @param sid [Integer] the span ID
    # @param level [Integer] default 1
    # @param baggage [Hash] baggage applied to this trace
    #
    def initialize(
      trace_id: Trace.generate_trace_id,
      span_id: Trace.generate_span_id,
      trace_flags: nil, #Todo - implement traceflags
      tracestate: nil,# Todo - implement tracestates
      remote: false,
      level: 1,
      baggage: {}
      )
      @trace_id = trace_id
      @span_id = trace_id
      @trace_flags = trace_flags
      @tracestate = tracestate
      @remote = remote
      @level = Integer(level || 1)
      @baggage = baggage || {}
    end

    def trace_id_header
      ::Instana::Util.id_to_header(@trace_id)
    end

    def span_id_header
      ::Instana::Util.id_to_header(@span_id)
    end

    def trace_parent_header
      trace = (@baggage[:external_trace_id] || trace_id_header).rjust(32, '0')
      parent = span_id_header.rjust(16, '0')
      flags = @level == 1 ? "01" : "00"

      "00-#{trace}-#{parent}-#{flags}"
    end

    def trace_state_header
      external_state = @baggage[:external_state] || ''
      state = external_state.split(/,/)

      if @level == 1
        state = state.reject { |s| s.start_with?('in=') }
        state.unshift("in=#{trace_id_header};#{span_id_header}")
      end

      state.take(32).reject { |v| v.nil? }.join(',')
    end

    def to_hash
      { :trace_id => @trace_id, :span_id => @span_id }
    end

    def valid?
      @baggage && @trace_id && !@trace_id.emtpy?
    end

    def active?
      @level == 1
    end
  end
end
