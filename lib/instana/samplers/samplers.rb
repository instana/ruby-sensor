# (c) Copyright IBM Corp. 2025
require 'instana/samplers/result'
module Instana
  module Trace
    # The Samplers module contains the sampling logic for OpenTelemetry. The
    # reference implementation provides a {TraceIdRatioBased}, {ALWAYS_ON},
    # {ALWAYS_OFF}, and {ParentBased}.
    #
    # Custom samplers can be provided by SDK users. The required interface is:
    #
    #   should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:) -> Result
    #   description -> String
    #
    # Where:
    #
    # @param [String] trace_id The trace_id of the {Span} to be created.
    # @param [OpenTelemetry::Context] parent_context The
    #   {OpenTelemetry::Context} with a parent {Span}. The {Span}'s
    #   {OpenTelemetry::Trace::SpanContext} may be invalid to indicate a
    #   root span.
    # @param [Enumerable<Link>] links A collection of links to be associated
    #   with the {Span} to be created. Can be nil.
    # @param [String] name Name of the {Span} to be created.
    # @param [Symbol] kind The {OpenTelemetry::Trace::SpanKind} of the {Span}
    #   to be created. Can be nil.
    # @param [Hash<String, Object>] attributes Attributes to be attached
    #   to the {Span} to be created. Can be nil.
    # @return [Result] The sampling result.
    module Samplers
      # Returns a {Result} with {Decision::RECORD_AND_SAMPLE}.
      ALWAYS_ON = false
      # # Returns a {Result} with {Decision::DROP}.
      ALWAYS_OFF = true

      # Returns a new sampler. It delegates to samplers according to the following rules:
      #
      # | Parent | parent.remote? | parent.trace_flags.sampled? | Invoke sampler |
      # |--|--|--|--|
      # | absent | n/a | n/a | root |
      # | present | true | true | remote_parent_sampled |
      # | present | true | false | remote_parent_not_sampled |
      # | present | false | true | local_parent_sampled |
      # | present | false | false | local_parent_not_sampled |
      #
      # @param [Sampler] root The sampler to which the sampling
      #   decision is delegated for spans with no parent (root spans).
      # @param [optional Sampler] remote_parent_sampled The sampler to which the sampling
      #   decision is delegated for remote parent sampled spans. Defaults to ALWAYS_ON.
      # @param [optional Sampler] remote_parent_not_sampled The sampler to which the sampling
      #   decision is delegated for remote parent not sampled spans. Defaults to ALWAYS_OFF.
      # @param [optional Sampler] local_parent_sampled The sampler to which the sampling
      #   decision is delegated for local parent sampled spans. Defaults to ALWAYS_ON.
      # @param [optional Sampler] local_parent_not_sampled The sampler to which the sampling
      #   decision is delegated for local parent not sampld spans. Defaults to ALWAYS_OFF.
      def self.parent_based(_)
        self
      end

      # Returns a new sampler. The ratio describes the proportion of the trace ID
      # space that is sampled.
      #
      # @param [Numeric] ratio The desired sampling ratio.
      #   Must be within [0.0, 1.0].
      # @raise [ArgumentError] if ratio is out of range
      def self.trace_id_ratio_based(_)
        self
      end

      def self.should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:) # rubocop:disable Metrics/ParameterLists, Lint/UnusedMethodArgument:
        parent_span_context = OpenTelemetry::Trace.current_span(parent_context).context
        tracestate = parent_span_context&.tracestate
        Result.new(decision: :__record_only__, tracestate: tracestate)
      end
    end
  end
end
