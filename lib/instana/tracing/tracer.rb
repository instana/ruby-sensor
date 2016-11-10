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

    ##
    # start_or_continue_trace
    #
    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    def start_or_continue_trace(name, kvs = {}, parent_id = nil, &block)
      log_start_or_continue(name, kvs, parent_id)
      block.call
    rescue Exception => e
      log_error(e)
      raise
    ensure
      log_end(name)
    end

    ##
    # trace
    #
    # Trace a block of code withing the context of the exiting trace
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

    ##
    # log_start_or_continue
    #
    # Will start a new trace or continue an on-going one (such as
    # from incoming remote requests with context headers).
    #
    def log_start_or_continue(name, kvs = {}, parent_id = nil)
      @trace = ::Instana::Trace.new(name, kvs, parent_id)
    end

    ##
    # log_entry
    #
    # Will establish a new span as a child of the current span
    # in an existing trace
    #
    def log_entry(name, kvs = {})
      @trace.new_span(name, kvs)
    end

    ##
    # log_info
    #
    # Add info to the current span
    #
    def log_info(kvs)
      @trace.add_info(kvs)
    end

    ##
    # log_error
    #
    # Add error to the current span
    #
    def log_error(e)
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
      @trace.finish(kvs)
      Instana.processor.add(@trace)
    end
  end
end
