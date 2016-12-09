require "instana/thread_local"
require "instana/tracing/trace"
require "instana/tracing/span"

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
    def log_async_entry(name, kvs, incoming_context = nil)
      return unless tracing?
      self.current_trace.new_async_span(name, kvs)
    end

    # Add info to an asynchronous span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    # @param t_context [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #   This can be retrieved by using ::Instana.tracer.context
    #
    def log_async_info(kvs, ids)
      # Asynchronous spans can persist longer than the parent
      # trace.  With the trace ID, we check the current trace
      # but otherwise, we search staged traces.

      if tracing? && self.current_trace.id == ids[:trace_id]
        self.current_trace.add_async_info(kvs, ids)
      else
        trace = ::Instana.processor.staged_trace(ids)
        trace.add_async_info(kvs, ids)
      end
    end

    # Add an error to an asynchronous span
    #
    # @param e [Exception] Add exception to the current span
    # @param ids [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    def log_async_error(e, ids)
      # Asynchronous spans can persist longer than the parent
      # trace.  With the trace ID, we check the current trace
      # but otherwise, we search staged traces.

      if tracing? && self.current_trace.id == ids[:trace_id]
        self.current_trace.add_async_error(e, ids)
      else
        trace = ::Instana.processor.staged_trace(ids)
        trace.add_async_error(e, ids)
      end
    end

    # Closes out an asynchronous span
    #
    # @param name [String] the name of the async span to exit (close out)
    # @param kvs [Hash] list of key values to be reported in the span
    # @param ids [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    def log_async_exit(name, kvs, ids)
      # An asynchronous span can end after the current trace has
      # already completed so we make sure that we end the span
      # on the right trace.

      if tracing? && (self.current_trace.id == ids[:trace_id])
        self.current_trace.end_async_span(kvs, ids)
      else
        # Different trace from current so find the staged trace
        # and close out the span on it.
        trace = ::Instana.processor.staged_trace(ids)
        if trace
          trace.end_async_span(kvs, ids)
        else
          ::Instana.logger.debug "log_async_exit: Couldn't find staged trace. #{ids.inspect}"
        end
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

    # Retrieve the current context of the tracer.
    #
    def context
      { :trace_id => self.current_trace.id,
        :span_id => self.current_trace.current_span_id }
    end

    # Take the current trace_id and convert it to a header compatible
    # format.
    #
    # @return [String] a hexadecimal representation of the current trace ID
    #
    def trace_id_header
      id_to_header(trace_id)
    end

    # Take the current span_id and convert it to a header compatible
    # formate.
    #
    # @return [String] a hexadecimal representation of the current span ID
    #
    def span_id_header
      id_to_header(span_id)
    end

    # Convert an ID to a value appropriate to pass in a header.
    #
    # @param id [Integer] the id to be converted
    #
    # @return [String]
    #
    def id_to_header(id)
      unless id.is_a?(Integer) || id.is_a?(String)
        Instana.logger.debug "id_to_header received a #{id.class}: returning empty string"
        return String.new
      end
      [id.to_i].pack('q>').unpack('H*')[0]
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # Convert a received header value into a valid ID
    #
    # @param header_id [String] the header value to be converted
    #
    # @return [Integer]
    #
    def header_to_id(header_id)
      if !header_id.is_a?(String)
        Instana.logger.debug "header_to_id received a #{header_id.class}: returning 0"
        return 0
      end
      [header_id].pack("H*").unpack("q>")[0]
    rescue => e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
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
