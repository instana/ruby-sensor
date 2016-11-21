require "instana/thread_local"
require "instana/tracing/trace"
require "instana/tracing/span"

module Instana
  class Tracer
    extend ::Instana::ThreadLocal

    thread_local :trace

    #######################################
    # Tracing blocks helper methods
    #######################################

    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash, {}] list of key values to be reported in the span
    # @param incoming_context [Hash, {}] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :parent_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
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
    # @param kvs [Hash, {}] list of key values to be reported in this new span
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
    # @param kvs [Hash, {}] list of key values to be reported in the span
    # @param incoming_context [Hash, {}] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :parent_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :parent_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def log_start_or_continue(name, kvs = {}, incoming_context = {})
      return unless ::Instana.agent.ready?
      @trace = ::Instana::Trace.new(name, kvs, incoming_context)
    end

    # Will establish a new span as a child of the current span
    # in an existing trace
    #
    def log_entry(name, kvs = {})
      return unless tracing?
      @trace.new_span(name, kvs)
    end

    ##
    # log_info
    #
    # Add info to the current span
    #
    def log_info(kvs)
      return unless tracing?
      @trace.add_info(kvs)
    end

    ##
    # log_error
    #
    # Add error to the current span
    #
    def log_error(e)
      return unless tracing?
      @trace.add_error(e)
    end

    ##
    # log_exit
    #
    # Will close out the current span
    #
    # Note: name isn't really required but helps keep sanity that
    # we're closing out the span that we really want to close out.
    #
    def log_exit(name, kvs = {})
      return unless tracing?
      @trace.end_span(kvs)
    end

    ##
    # log_end
    #
    # Closes out the current span in the current trace
    # and queues the trace for reporting
    #
    # Note: name isn't really required but helps keep sanity that
    # we're closing out the span that we really want to close out.
    #
    def log_end(name, kvs = {})
      return unless tracing?

      @trace.finish(kvs)
      Instana.processor.add(@trace)
      @trace = nil
    end

    ##
    # tracing?
    #
    # Indicates if we're are currently in the process of
    # collecting a trace.  This is false when the host agent isn
    # available.
    #
    def tracing?
      # The non-nil value of this instance variable
      # indicates if we are currently tracing
      # in this thread or not.
      @trace ? true : false
    end
  end
end
