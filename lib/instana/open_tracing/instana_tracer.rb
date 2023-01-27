# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'delegate'
# :nocov:
module OpenTracing
  class InstanaTracer < SimpleDelegator
    Span = ::Instana::Span

    # Start a new span
    #
    # @param operation_name [String] The name of the operation represented by the span
    # @param child_of [Span] A span to be used as the ChildOf reference
    # @param start_time [Time] the start time of the span
    # @param tags [Hash] Starting tags for the span
    #
    # @return [Span]
    #
    def start_span(operation_name, child_of: nil, start_time: ::Instana::Util.now_in_ms, tags: nil)
      new_span = if child_of && (child_of.is_a?(::Instana::Span) || child_of.is_a?(::Instana::SpanContext))
                   Span.new(operation_name, parent_ctx: child_of, start_time: start_time)
                 else
                   Span.new(operation_name, start_time: start_time)
                 end
      new_span.set_tags(tags) if tags
      new_span
    end

    # Start a new span which is the child of the current span
    #
    # @param operation_name [String] The name of the operation represented by the span
    # @param child_of [Span] A span to be used as the ChildOf reference
    # @param start_time [Time] the start time of the span
    # @param tags [Hash] Starting tags for the span
    #
    # @return [Span]
    #
    def start_active_span(operation_name, child_of: active_span, start_time: ::Instana::Util.now_in_ms, tags: nil)
      ::Instana.tracer.current_span = start_span(operation_name, child_of: child_of, start_time: start_time, tags: tags)
      block_given? ? yield(::Instana.tracer.current_span) : ::Instana.tracer.current_span
    end

    # Returns the currently active span
    #
    # @return [Span]
    #
    def active_span
      ::Instana.tracer.current_span
    end

    # Inject a span into the given carrier
    #
    # @param span_context [SpanContext]
    # @param format [OpenTracing::FORMAT_TEXT_MAP, OpenTracing::FORMAT_BINARY, OpenTracing::FORMAT_RACK]
    # @param carrier [Carrier]
    #
    def inject(span_context, format, carrier)
      case format
      when OpenTracing::FORMAT_TEXT_MAP, OpenTracing::FORMAT_BINARY
        ::Instana.logger.debug 'Unsupported inject format'
      when OpenTracing::FORMAT_RACK
        carrier['X-Instana-T'] = ::Instana::Util.id_to_header(span_context.trace_id)
        carrier['X-Instana-S'] = ::Instana::Util.id_to_header(span_context.span_id)
      else
        ::Instana.logger.debug 'Unknown inject format'
      end
    end

    # Extract a span from a carrier
    #
    # @param format [OpenTracing::FORMAT_TEXT_MAP, OpenTracing::FORMAT_BINARY, OpenTracing::FORMAT_RACK]
    # @param carrier [Carrier]
    #
    # @return [SpanContext]
    #
    def extract(format, carrier)
      case format
      when OpenTracing::FORMAT_TEXT_MAP, OpenTracing::FORMAT_BINARY
        ::Instana.logger.debug 'Unsupported extract format'
      when OpenTracing::FORMAT_RACK
        ::Instana::SpanContext.new(::Instana::Util.header_to_id(carrier['HTTP_X_INSTANA_T']),
                                   ::Instana::Util.header_to_id(carrier['HTTP_X_INSTANA_S']))
      else
        ::Instana.logger.debug 'Unknown inject format'
        nil
      end
    end

    def method_missing(method, *args, **kwargs, &block)
      ::Instana.logger.warn { "You are invoking `#{m}` on Instana::Tracer via OpenTracing." }
      super(method, *args, **kwargs, &block)
    end

    def respond_to_missing?(*)
      super(method)
    end
  end
end
# :nocov:
