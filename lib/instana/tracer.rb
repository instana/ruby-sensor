require "instana/thread_local"
require "instana/tracing/span"
require "instana/tracing/span_context"

module Instana
  class Tracer
    extend ::Instana::ThreadLocal

    thread_local :current_span

    # Support ::Instana::Tracer.xxx call style for the instantiated tracer
    class << self
      def method_missing(method, *args, &block)
        if ::Instana.tracer.respond_to?(method)
          ::Instana.tracer.send(method, *args, &block)
        else
          super
        end
      end
    end

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
    def start_or_continue_trace(name, kvs = {}, incoming_context = nil, &block)
      log_start_or_continue(name, kvs, incoming_context)
      yield
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
      yield
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
    # @param incoming_context [SpanContext or Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def log_start_or_continue(name, kvs = {}, incoming_context = nil)
      return if !::Instana.agent.ready? || !::Instana.config[:tracing][:enabled]
      ::Instana.logger.debug { "#{__method__} passed a block.  Use `start_or_continue` instead!" } if block_given?

      # Handle the potential variations on `incoming_context`
      if incoming_context
        if incoming_context.is_a?(Hash)
          if !incoming_context.empty?
            parent_context = SpanContext.new(incoming_context[:trace_id], incoming_context[:span_id], incoming_context[:level])
          end
        else
          parent_context = incoming_context
        end
      end

      if parent_context
        self.current_span = Span.new(name, parent_ctx: parent_context)
      else
        self.current_span = Span.new(name)
      end
      self.current_span.set_tags(kvs) unless kvs.empty?
      self.current_span
    end

    # Will establish a new span as a child of the current span
    # in an existing trace
    #
    # @param name [String] the name of the span to create
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_entry(name, kvs = nil, start_time = ::Instana::Util.now_in_ms, child_of = nil)
      return unless self.current_span || child_of

      if child_of && (child_of.is_a?(::Instana::Span) || child_of.is_a?(::Instana::SpanContext))
        new_span = Span.new(name, parent_ctx: child_of, start_time: start_time)
      else
        new_span = Span.new(name, parent_ctx: self.current_span, start_time: start_time)
      end
      new_span.set_tags(kvs) if kvs
      self.current_span = new_span
    end

    # Add info to the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_info(kvs)
      return unless self.current_span
      self.current_span.set_tags(kvs)
    end

    # Add an error to the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def log_error(e)
      return unless self.current_span
      self.current_span.add_error(e)
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
      return unless self.current_span

      if ENV.key?('INSTANA_DEBUG') || ENV.key?('INSTANA_TEST')
        unless self.current_span.name == name
          ::Instana.logger.debug "Span mismatch: Attempt to exit #{name} span but #{self.current_span.name} is active."
        end
      end

      self.current_span.set_tags(kvs)
      self.current_span.close

      if self.current_span.parent
        self.current_span = self.current_span.parent
      else
        self.current_span = nil
      end
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
    def log_end(name, kvs = {}, end_time = ::Instana::Util.now_in_ms)
      return unless self.current_span

      if ENV.key?('INSTANA_DEBUG') || ENV.key?('INSTANA_TEST')
        unless self.current_span.name == name
          ::Instana.logger.debug "Span mismatch: Attempt to end #{name} span but #{self.current_span.name} is active."
        end
      end

      self.current_span.set_tags(kvs)
      self.current_span.close(end_time)
      self.current_span = nil
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
      return unless self.current_span

      new_span = Span.new(name, parent_ctx: self.current_span)
      new_span.set_tags(kvs) unless kvs.empty?
      new_span
    end

    # Add info to an asynchronous span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span for this Async op (previously returned from `log_async_entry`)
    #
    def log_async_info(kvs, span)
      span.set_tags(kvs)
    end

    # Add an error to an asynchronous span
    #
    # @param e [Exception] Add exception to the current span
    # @param span [Span] the span for this Async op (previously returned from `log_async_entry`)
    #
    def log_async_error(e, span)
      span.add_error(e)
    end

    # Closes out an asynchronous span
    #
    # @param name [String] the name of the async span to exit (close out)
    # @param kvs [Hash] list of additional key/values to be reported in the span (or use {})
    # @param span [Span] the span for this Async op (previously returned from `log_async_entry`)
    #
    def log_async_exit(_name, kvs, span)
      span.set_tags(kvs) unless kvs.empty?
      span.close
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
    def start_span(operation_name, child_of: nil, start_time: ::Instana::Util.now_in_ms, tags: nil)
      if child_of && (child_of.is_a?(::Instana::Span) || child_of.is_a?(::Instana::SpanContext))
        new_span = Span.new(operation_name, parent_ctx: child_of, start_time: start_time)
      else
        new_span = Span.new(operation_name, start_time: start_time)
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
    def start_active_span(operation_name, child_of: self.current_span, start_time: ::Instana::Util.now_in_ms, tags: nil)
      self.current_span = start_span(operation_name, child_of: child_of, start_time: start_time, tags: tags)
    end

    # Returns the currently active span
    #
    # @return [Span]
    #
    def active_span
      self.current_span
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
      self.current_span ? true : false
    end

    # Indicates if we're tracing and the current span name matches
    # <name>
    #
    # @param name [Symbol] the name to check against the current span
    #
    # @return [Boolean]
    #
    def tracing_span?(name)
      if self.current_span
        return self.current_span.name == name
      end
      false
    end

    # Retrieve the current context of the tracer.
    #
    # @return [SpanContext] or nil if not tracing
    #
    def context
      return unless self.current_span
      self.current_span.context
    end

    # Take the current trace_id and convert it to a header compatible
    # format.
    #
    # @return [String] a hexadecimal representation of the current trace ID
    #
    def trace_id_header
      if self.current_span
        self.current_span.context.trace_id_header
      else
        ""
      end
    end

    # Take the current span_id and convert it to a header compatible
    # formate.
    #
    # @return [String] a hexadecimal representation of the current span ID
    #
    def span_id_header
      if self.current_span
        self.current_span.context.span_id_header
      else
        ""
      end
    end

    # Returns the trace ID for the active trace (if there is one),
    # otherwise nil.
    #
    def trace_id
      self.current_span ? self.current_span.id : nil
      ::Instana.logger.debug("tracer.trace_id will deprecated in a future version.")
    end

    # Returns the current [Span] ID for the active trace (if there is one),
    # otherwise nil.
    #
    def span_id
      self.current_span  ? self.current_span.span_id : nil
      ::Instana.logger.debug("tracer.span_id will deprecated in a future version.")
    end

    # Used in the test suite, this resets the tracer to non-tracing state.
    #
    def clear!
      self.current_span = nil
    end
  end
end
