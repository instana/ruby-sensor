# (c) Copyright IBM Corp. 2025
require 'opentelemetry/context'
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

    # Returns the current span from the current or provided context
    #
    # @param [optional Context] context The context to lookup the current
    #   {Span} from. Defaults to Context.current
    def current_span(context = nil)
      context ||= OpenTelemetry::Context.current
      context.value(CURRENT_SPAN_KEY) || Span::INVALID
    end

    # Returns a context containing the span, derived from the optional parent
    # context, or the current context if one was not provided.
    #
    # @param [optional Context] context The context to use as the parent for
    #   the returned context
    def context_with_span(span, parent_context:  OpenTelemetry::Context.current)
      parent_context.set_value(CURRENT_SPAN_KEY, span)
    end

    # Activates/deactivates the Span within the current Context, which makes the "current span"
    # available implicitly.
    #
    # On exit, the Span that was active before calling this method will be reactivated.
    #
    # @param [Span] span the span to activate
    # @yield [span, context] yields span and a context containing the span to the block.
    def with_span(span)
      Context.with_value(CURRENT_SPAN_KEY, span) { |c, s| yield s, c }
    end

    # Wraps a SpanContext with an object implementing the Span interface. This is done in order
    # to expose a SpanContext as a Span in operations such as in-process Span propagation.
    #
    # @param [SpanContext] span_context SpanContext to be wrapped
    #
    # @return [Span]
    def non_recording_span(span_context)
      Span.new(span_context: span_context)
    end
  end
end

require 'instana/trace/span_context'
require 'instana/trace/span_kind'
require 'instana/trace/span'
require 'instana/trace/tracer'
