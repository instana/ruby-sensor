# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'forwardable'

module Instana
  class Processor
    extend Forwardable
    def_delegators :@queue, :empty?

    def initialize(logger: ::Instana.logger)
      # The main queue before being reported to the
      # host agent.  Spans in this queue are complete
      # and ready to be sent.
      @queue = Queue.new

      # This is the maximum number of spans we send to the host
      # agent at once.
      @batch_size = 3000
      @logger = logger
      @pid = Process.pid

      @spans_opened = Concurrent::AtomicFixnum.new(0)
      @spans_closed = Concurrent::AtomicFixnum.new(0)
    end

    # Note that we've started a new span. Used to
    # generate monitoring metrics.
    def on_start(_)
      @spans_opened.increment
    end

    def on_finish(span)
      # :nocov:
      if @pid != Process.pid
        @logger.info("Proces `#{@pid}` has forked into #{Process.pid}. Running post fork hook.")
        ::Instana.config[:post_fork_proc].call
        @pid = Process.pid
      end
      # :nocov:

      @spans_closed.increment
      @queue.push(span)
    end

    # Clears and retrieves metrics associated with span creation and submission
    def span_metrics
      response = {
        opened: @spans_opened.value,
        closed: @spans_closed.value,
        filtered: 0,
        dropped: 0
      }

      @spans_opened.value = 0
      @spans_closed.value = 0

      response
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
    def send(&block)
      return if @queue.empty? || ENV.key?('INSTANA_TEST')

      # Retrieve all spans for queued traces
      spans = queued_spans

      # Report spans in batches
      spans.each_slice(@batch_size, &block)
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
      until @queue.empty?
        # Non-blocking pop; ignore exception
        span = begin
          @queue.pop(true)
        rescue
          nil
        end
        spans << span.raw if span.is_a?(Span) && span.context.level == 1
      end

      spans
    end

    # Removes all traces from the @queue.  Used in the
    # test suite to reset state.
    #
    def clear!
      @spans_opened.value = 0
      @spans_closed.value = 0

      until @queue.empty?
        # Non-blocking pop; ignore exception
        begin
          @queue.pop(true)
        rescue
          nil
        end
      end
    end
  end
end
