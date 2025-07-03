# (c) Copyright IBM Corp. 2025

require 'opentelemetry/trace/tracer'
require 'instana/trace/span'
require "instana/trace/span_context"
require 'opentelemetry/context'

module Instana
  class Tracer < OpenTelemetry::Trace::Tracer
    class << self
      def method_missing(method, *args, &block) # rubocop:disable Style/MissingRespondToMissing
        if ::Instana.tracer.respond_to?(method)
          ::Instana.tracer.send(method, *args, &block)
        else
          super
        end
      end
    end

    def initialize(_name, _version, tracer_provider, logger = Instana.logger)
      super()
      @tracer_provider = tracer_provider
      @current_span = Concurrent::ThreadLocalVar.new
      @logger = logger
    end

    # @return [Instana::Span, NilClass] the current active span or nil if we are not tracing
    def current_span
      @current_span.value
    end

    # @param [Instana::Span, NilClas] v the new current span
    # Set the value of the current span
    def current_span=(value)
      @current_span.value = value
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
    def start_or_continue_trace(name, kvs = {}, incoming_context = nil)
      span = log_start_or_continue(name, kvs, incoming_context)
      yield(span)
    rescue Exception => e # rubocop:disable Lint/RescueException
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
    def trace(name, kvs = {})
      span = log_entry(name, kvs)
      yield(span)
    rescue Exception => e # rubocop:disable Lint/RescueException
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
          unless incoming_context.empty?
            parent_context = SpanContext.new(
              trace_id: incoming_context[:trace_id],
              span_id: incoming_context[:span_id],
              level: incoming_context[:level],
              baggage: {
                external_trace_id: incoming_context[:external_trace_id],
                external_state: incoming_context[:external_state]
              }
            )
          end
        else
          parent_context = incoming_context
        end
      end

      self.current_span = if parent_context
                            Span.new(name, parent_context)
                          else
                            Span.new(name)
                          end

      current_span.set_tags(kvs) unless kvs.empty?
      current_span
    end

    # Will establish a new span as a child of the current span
    # in an existing trace
    #
    # @param name [String, Symbol] the name of the span to create
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_entry(name, kvs = nil, _start_time = ::Instana::Util.now_in_ms, child_of = nil)
      return unless tracing? || child_of

      new_span = if child_of.nil? && !current_span.nil?
                   Span.new(name, current_span)
                 else
                   Span.new(name, child_of)
                 end
      new_span.set_tags(kvs) if kvs
      self.current_span = new_span
    end

    # Add info to the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_info(kvs)
      return unless current_span

      current_span.set_tags(kvs)
    end

    # Add an error to the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def log_error(error)
      return unless current_span

      current_span.record_exception(error)
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
      return unless current_span

      if current_span.name != name
        @logger.warn "Span mismatch: Attempt to end #{name} span but #{current_span.name} is active."
      end

      current_span.set_tags(kvs)
      current_span.close

      self.current_span = current_span.parent || nil
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
      return unless current_span

      if current_span.name != name
        @logger.warn "Span mismatch: Attempt to end #{name} span but #{current_span.name} is active."
      end

      current_span.set_tags(kvs)
      current_span.close(end_time)
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
      return unless tracing?

      new_span = Span.new(name, current_span)
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
    def log_async_error(error, span)
      span.record_exception(error)
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
      (current_span ? true : false) ||
        (::Instana.config[:allow_exit_as_root] && ::Instana.config[:tracing][:enabled])
    end

    # Indicates if we're tracing and the current span name matches
    # <name>
    #
    # @param name [Symbol] the name to check against the current span
    #
    # @return [Boolean]
    #
    def tracing_span?(name)
      if current_span
        return current_span.name == name
      end

      false
    end

    # Retrieve the current context of the tracer.
    #
    # @return [SpanContext] or nil if not tracing
    #
    def context
      return unless current_span

      current_span.context
    end

    # Used in the test suite, this resets the tracer to non-tracing state.
    #
    def clear!
      self.current_span = nil
    end

    def in_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil)
      return if !::Instana.agent.ready? || !::Instana.config[:tracing][:enabled]

      super
    end

    def start_span(name, with_parent: nil, attributes: nil, links: nil, start_timestamp: ::Instana::Util.now_in_ms, kind: nil) # rubocop:disable Metrics/ParameterLists
      return if !::Instana.agent.ready? || !::Instana.config[:tracing][:enabled]

      with_parent ||= OpenTelemetry::Context.current
      name ||= 'empty'
      kind ||= :internal
      start_timestamp ||= ::Instana::Util.now_in_ms
      self.current_span = @tracer_provider.internal_start_span(name, kind, attributes, links, start_timestamp, with_parent, @instrumentation_scope)
    end
  end
end
