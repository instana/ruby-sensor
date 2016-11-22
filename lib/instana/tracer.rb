require "instana/thread_local"
require "instana/tracing/trace"
require "instana/tracing/span"

module Instana
  class Tracer
    extend ::Instana::ThreadLocal

    thread_local :current_trace

    #######################################
    # Tracing blocks helper methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :parent_id from the following:
    #     @:trace_id the trace ID (must be an unsigned hex-string)
    #     :parent_id the ID of the parent span (must be an unsigned hex-string)
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
    # Lower level tracing methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :parent_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :parent_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def log_start_or_continue(name, kvs = {}, incoming_context = {})
      return unless ::Instana.agent.ready?
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

    # Will close out the current span
    #
    # @note `name` isn't really required but helps keep sanity that
    # we're closing out the span that we really want to close out.
    #
    # @param name [String] the name of the span to exit (close out)
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def log_exit(name, kvs = {})
      return unless tracing?
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
    def log_end(name, kvs = {})
      return unless tracing?

      self.current_trace.finish(kvs)
      Instana.processor.add(self.current_trace)
      self.current_trace = nil
    end

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
  end
end
