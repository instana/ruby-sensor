# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "instana/tracing/span"
require "instana/tracing/span_context"

module Instana
  class Tracer
    # Support ::Instana::Tracer.xxx call style for the instantiated tracer
    class << self
      def method_missing(method, *args, **kwargs, &block)
        if ::Instana.tracer.respond_to?(method)
          ::Instana.tracer.send(method, *args, **kwargs, &block)
        else
          super
        end
      end
    end

    def initialize(logger: Instana.logger)
      @current_span = Concurrent::ThreadLocalVar.new
      @logger = logger
    end

    # @return [Instana::Span, NilClass] the current active span or nil if we are not tracing
    def current_span
      @current_span.value
    end

    # @param [Instana::Span, NilClas] v the new current span
    # Set the value of the current span
    def current_span=(v)
      @current_span.value = v
    end

    #######################################
    # Tracing blocks API methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String, Symbol] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     @:trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def start_or_continue_trace(name, kvs = {}, incoming_context = nil, &block)
      span = log_start_or_continue(name, kvs, incoming_context)
      yield(span)
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
    # @param name [String, Symbol] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in this new span
    #
    def trace(name, kvs = {}, &block)
      span = log_entry(name, kvs)
      yield(span)
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
    # @param name [String, Symbol] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [SpanContext or Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def log_start_or_continue(name, kvs = {}, incoming_context = nil)
      return if !::Instana.agent.ready? || !::Instana.config[:tracing][:enabled]

      # Handle the potential variations on `incoming_context`
      if incoming_context
        if incoming_context.is_a?(Hash)
          if !incoming_context.empty?
            parent_context = SpanContext.new(
              incoming_context[:trace_id],
              incoming_context[:span_id],
              incoming_context[:level],
              {
                external_trace_id: incoming_context[:external_trace_id],
                external_state: incoming_context[:external_state]
              }
            )
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
    # @param name [String, Symbol] the name of the span to create
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_entry(name, kvs = nil, start_time = ::Instana::Util.now_in_ms, child_of = nil)
      return unless self.current_span || child_of

      new_span = if child_of.is_a?(::Instana::Span) || child_of.is_a?(::Instana::SpanContext)
                   Span.new(name, parent_ctx: child_of, start_time: start_time)
                 else
                   Span.new(name, parent_ctx: self.current_span, start_time: start_time)
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
    # @param name [String, Symbol] the name of the span to exit (close out)
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_exit(name, kvs = {})
      return unless self.current_span

      if self.current_span.name != name
        @logger.warn "Span mismatch: Attempt to end #{name} span but #{self.current_span.name} is active."
      end

      self.current_span.set_tags(kvs)
      self.current_span.close

      self.current_span = self.current_span.parent || nil
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

      if self.current_span.name != name
        @logger.warn "Span mismatch: Attempt to end #{name} span but #{self.current_span.name} is active."
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

    # Used in the test suite, this resets the tracer to non-tracing state.
    #
    def clear!
      self.current_span = nil
    end
  end
end
