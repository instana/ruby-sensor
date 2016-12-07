require 'thread'

module Instana
  class Processor

    def initialize
      # The main queue before being reported to the
      # host agent.  Traces in this queue are complete
      # and ready to be sent.
      @queue = Queue.new

      # The staging queue that holds traces that have completed
      # but still have outstanding async spans.
      # Traces that have been in this queue for more than
      # 5 minutes are discarded.
      @staging_queue = Set.new

      # No access to the @staging_queue until this lock
      # is taken.
      @staging_lock = Mutex.new
    end

    # Adds a trace to the queue to be processed and
    # sent to the host agent
    #
    # @param [Trace] the trace to be added to the queue
    def add(trace)
      ::Instana.logger.trace("Queuing completed trace id: #{trace.id}")
      @queue.push(trace)
    end

    # Adds a trace to the staging queue.
    #
    # @param [Trace] the trace to be added to the queue
    def stage(trace)
      ::Instana.logger.trace("Staging incomplete trace id: #{trace.id}")
      @staging_queue.push(trace)
    end

    # Retrieves a staged trace from the staging queue.  Staged traces
    # are traced that have completed but may have outstanding
    # asynchronous spans.
    #
    # @param ids [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    def staged_trace(ids)
      candidate = nil
      @staging_lock.synchronize {
        @staging_queue.each do |trace|
          if trace.id == ids[:trace_id]
            candidate = trace
          end
        end
      }
      unless candidate
        ::Instana.logger.trace("Couldn't find staged trace with trace_id: #{ids[:trace_id]}")
      end
      candidate
    end

    ##
    # send
    #
    # Sends all traces in @queue to the host
    # agent
    #
    # FIXME: Add limits checking here in regards to:
    #   - Max HTTP Post size
    #   - Out of control/growing queue
    #   - Prevent another run of the timer while this is running
    #
    def send
      return if @queue.empty?

      size = @queue.size
      if size > 100
        Instana.logger.debug "Trace queue is #{size}"
      end

      # Retrieve all queued spans for completed traces
      spans = queued_spans

      # Check staged traces if any have completed
      if @staging_queue.size
        @staging_queue.delete_if do |t|
          if t.complete?
            t.spans.each do |s|
              spans << s.raw
            end
            true
          elsif t.discard?
            ::Instana.logger.trace("Discarding trace with uncompleted async spans over 5 mins old. id: #{t.id}")
            true
          else
            false
          end
        end
      end

      ::Instana.agent.report_spans(spans)
    end

    # Get the number traces currently in the queue
    #
    # @return [Integer] the queue size
    def queue_count
      @queue.size
    end

    # Retrieves all of the traces in @queue and returns
    # the sum of their raw spans.
    # This is used by Processor::send and in the test suite.
    # Note that traces retrieved with this method are removed
    # entirely from the queue.
    #
    # @return [Array] An array of [Span] or empty
    #
    def queued_spans
      return [] if @queue.empty?

      spans = []
      until @queue.empty? do
        # Non-blocking pop; ignore exception
        trace = @queue.pop(true) rescue nil
        trace.spans.each do |s|
          spans << s.raw
        end
      end
      spans
    end

    # Retrieves all of the traces that are in @queue.
    # Note that traces retrieved with this method are removed
    # entirely from the queue.
    #
    # @return [Array] An array of [Trace] or empty
    #
    def queued_traces
      return [] if @queue.empty?

      traces = []
      until @queue.empty? do
        # Non-blocking pop; ignore exception
        traces << @queue.pop(true) rescue nil
      end
      traces
    end

    # Removes all traces from the @queue.  Used in the
    # test suite.
    #
    def clear!
      return [] if @queue.empty?

      until @queue.empty? do
        # Non-blocking pop; ignore exception
        @queue.pop(true) rescue nil
      end
    end
  end
end
