require 'thread'

module Instana
  class Processor
    def initialize
      # The main queue before being reported to the
      # host agent.  Spans in this queue are complete
      # and ready to be sent.
      @queue = Queue.new

      # This is the maximum number of spans we send to the host
      # agent at once.
      @batch_size = 3000
    end

    # Adds a Set of spans to the queue
    #
    # @param [spans] - the trace to be added to the queue
    def add_spans(spans)
      spans.each { |span| @queue.push(span)}
    end

    # Adds a span to the span queue
    #
    # @param [Trace] - the trace to be added to the queue
    def add_span(span)
      # Occasionally, do a checkup on our background thread.
      if rand(10) > 8
        if ::Instana.agent.collect_thread.nil? || !::Instana.agent.collect_thread.alive?
          ::Instana.agent.spawn_background_thread
        end
      end
      @queue.push(span)
    end

    ##
    # send
    #
    # Sends all traces in @queue to the host agent
    #
    # FIXME: Add limits checking here in regards to:
    #   - Max HTTP Post size
    #   - Out of control/growing queue
    #   - Prevent another run of the timer while this is running
    #
    def send
      return if @queue.empty? || ENV.key?('INSTANA_TEST')

      # Retrieve all spans for queued traces
      spans = queued_spans

      # Report spans in batches
      batch = spans.shift(@batch_size)
      while !batch.empty? do
        ::Instana.agent.report_spans(batch)
        batch = spans.shift(@batch_size)
      end
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
        span = @queue.pop(true) rescue nil
        if span
          spans << span.raw
        end
      end
      spans
    end

    # Removes all traces from the @queue.  Used in the
    # test suite to reset state.
    #
    def clear!
      until @queue.empty? do
        # Non-blocking pop; ignore exception
        @queue.pop(true) rescue nil
      end
    end
  end
end
