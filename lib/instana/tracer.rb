require "instana/thread_local"
require "instana/tracing/trace"
require "instana/tracing/span"
require "instana/tracing/span_context"

module Instana
  class Tracer
    extend ::Instana::ThreadLocal

    thread_local :current_trace

    #######################################
    # Tracing blocks API methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     @:trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def start_or_continue_trace(name, kvs = {}, incoming_context = {}, &block)
      log_start_or_continue(name, kvs, incoming_context)
      block.call
    rescue Exception => e
      log_error(e)
      raise
    ensure
      log_end(name)
    end

    # Trace a block of code within the context of the exiting trace
    #
    # Example usage:
    #
    # ::Instana.tracer.trace(:dbwork, { :db_name => @db.name }) do
    #   @db.select(1)
    # end
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in this new span
    #
    def trace(name, kvs = {}, &block)
      log_entry(name, kvs)
      result = block.call
      result
    rescue Exception => e
      log_error(e)
      raise
    ensure
      log_exit(name)
    end

    #######################################
    # Lower level tracing API methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def log_start_or_continue(name, kvs = {}, incoming_context = {})
      return unless ::Instana.agent.ready?
      ::Instana.logger.debug "#{__method__} passed a block.  Use `start_or_continue` instead!" if block_given?
      self.current_trace = ::Instana::Trace.new(name, kvs, incoming_context)
    end

    # Will establish a new span as a child of the current span
    # in an existing trace
    #
    # @param name [String] the name of the span to create
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_entry(name, kvs = {})
      return unless tracing?
      self.current_trace.new_span(name, kvs)
    end

    # Add info to the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_info(kvs)
      return unless tracing?
      self.current_trace.add_info(kvs)
    end

    # Add an error to the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def log_error(e)
      return unless tracing?
      self.current_trace.add_error(e)
    end

    # Closes out the current span
    #
    # @note `name` isn't really required but helps keep sanity that
    # we're closing out the span that we really want to close out.
    #
    # @param name [String] the name of the span to exit (close out)
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_exit(name, kvs = {})
      return unless tracing?

      if ::Instana.debug? || ::Instana.test?
        unless current_span_name?(name)
          ::Instana.logger.debug "Span mismatch: Attempt to exit #{name} span but #{current_span.name} is active."
        end
      end

      self.current_trace.end_span(kvs)
    end

    # Closes out the current span in the current trace
    # and queues the trace for reporting
    #
    # @note `name` isn't really required but helps keep sanity that
    # we're ending the span that we really want to close out.
    #
    # @param name [String] the name of the span to end
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_end(name, kvs = {}, end_time = Time.now)
      return unless tracing?

      if ::Instana.debug? || ::Instana.test?
        unless current_span_name?(name)
          ::Instana.logger.debug "Span mismatch: Attempt to end #{name} span but #{current_span.name} is active."
        end
      end

      self.current_trace.finish(kvs, end_time)

      if !self.current_trace.has_async? ||
          (self.current_trace.has_async? && self.current_trace.complete?)
        Instana.processor.add(self.current_trace)
      else
        # This trace still has outstanding/uncompleted asynchronous spans.
        # Put it in the staging queue until the async span closes out or
        # 5 minutes has passed.  Whichever comes first.
        Instana.processor.stage(self.current_trace)
      end
      self.current_trace = nil
    end

    ###########################################################################
    # Asynchronous API methods
    ###########################################################################

    # Starts a new asynchronous span on the current trace.
    #
    # @param name [String] the name of the span to create
    # @param kvs [Hash] list of key values to be reported in the span
    #
    # @return [Hash] the context: Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    def log_async_entry(name, kvs)
      return unless tracing?
      self.current_trace.new_async_span(name, kvs)
    end

    # Add info to an asynchronous span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span for this Async op (previously returned
    #   from `log_async_entry`)
    #
    def log_async_info(kvs, span)
      # Asynchronous spans can persist longer than the parent
      # trace.  With the trace ID, we check the current trace
      # but otherwise, we search staged traces.

      if tracing? && self.current_trace.id == span.context.trace_id
        self.current_trace.add_async_info(kvs, span)
      else
        trace = ::Instana.processor.staged_trace(span.context.trace_id)
        trace.add_async_info(kvs, span)
      end
    end

    # Add an error to an asynchronous span
    #
    # @param e [Exception] Add exception to the current span
    # @param span [Span] the span for this Async op (previously returned
    #   from `log_async_entry`)
    #
    def log_async_error(e, span)
      # Asynchronous spans can persist longer than the parent
      # trace.  With the trace ID, we check the current trace
      # but otherwise, we search staged traces.

      if tracing? && self.current_trace.id == span.context.trace_id
        self.current_trace.add_async_error(e, span)
      else
        trace = ::Instana.processor.staged_trace(span.context.trace_id)
        trace.add_async_error(e, span)
      end
    end

    # Closes out an asynchronous span
    #
    # @param name [String] the name of the async span to exit (close out)
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span for this Async op (previously returned
    #   from `log_async_entry`)
    #
    def log_async_exit(name, kvs, span)
      # An asynchronous span can end after the current trace has
      # already completed so we make sure that we end the span
      # on the right trace.

      if tracing? && self.current_trace.id == span.context.trace_id
        self.current_trace.end_async_span(kvs, span)
      else
        # Different trace from current so find the staged trace
        # and close out the span on it.
        trace = ::Instana.processor.staged_trace(span.context.trace_id)
        if trace
          trace.end_async_span(kvs, span)
        else
          ::Instana.logger.debug "log_async_exit: Couldn't find staged trace. #{span.inspect}"
        end
      end
    end

    ###########################################################################
    # OpenTracing Support
    ###########################################################################

    # Start a new span
    #
    # @param operation_name [String] The name of the operation represented by the span
    # @param child_of [Span] A span to be used as the ChildOf reference
    # @param start_time [Time] the start time of the span
    # @param tags [Hash] Starting tags for the span
    #
    # @return [Span]
    #
    def start_span(operation_name, child_of: nil, start_time: Time.now, tags: nil)
      return unless ::Instana.agent.ready?

      if tracing?
        span = self.current_trace.new_span(operation_name, tags, start_time, child_of)
      else
        self.current_trace = ::Instana::Trace.new(operation_name, tags, nil, start_time)
        span = self.current_trace.current_span
      end
      span.set_tags(tags)
      span
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

    ###########################################################################
    # Helper methods
    ###########################################################################

    # Indicates if we're are currently in the process of
    # collecting a trace.  This is false when the host agent isn
    # available.
    #
    # @return [Boolean] true or false on whether we are currently tracing or not
    #
    def tracing?
      # The non-nil value of this instance variable
      # indicates if we are currently tracing
      # in this thread or not.
      self.current_trace ? true : false
    end

    # Indicates if we're tracing and the current span name matches
    # <name>
    #
    # @param name [Symbol] the name to check against the current span
    #
    # @return [Boolean]
    #
    def tracing_span?(name)
      if self.current_trace
        return self.current_trace.current_span.name == name
      end
      false
    end

    # Retrieve the current context of the tracer.
    #
    # @return [SpanContext] or nil if not tracing
    #
    def context
      return nil unless tracing?
      self.current_trace.current_span.context
    end

    # Take the current trace_id and convert it to a header compatible
    # format.
    #
    # @return [String] a hexadecimal representation of the current trace ID
    #
    def trace_id_header
      ::Instana::Util.id_to_header(trace_id)
    end

    # Take the current span_id and convert it to a header compatible
    # formate.
    #
    # @return [String] a hexadecimal representation of the current span ID
    #
    def span_id_header
      ::Instana::Util.id_to_header(span_id)
    end

    # Returns the trace ID for the active trace (if there is one),
    # otherwise nil.
    #
    def trace_id
      self.current_trace ? self.current_trace.id : nil
    end

    # Returns the current [Span] ID for the active trace (if there is one),
    # otherwise nil.
    #
    def span_id
      self.current_trace  ? current_trace.current_span_id : nil
    end

    # Helper method to retrieve the currently active span for the active trace.
    #
    def current_span
      self.current_trace ? self.current_trace.current_span : nil
    end

    # Indicates if the name of the current span matches <candidate>
    #
    def current_span_name?(candidate)
      self.current_trace &&  self.current_trace.current_span.name == candidate.to_sym
    end

    # Used in the test suite, this resets the tracer to non-tracing state.
    #
    def clear!
      self.current_trace = nil
    end
  end
end
