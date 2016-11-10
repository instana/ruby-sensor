require 'thread'

module Instana
  class Processor

    def initialize
      @queue = Queue.new
    end

    ##
    # add
    #
    # Adds a trace to the queue to be processed and
    # sent to the host agent
    #
    def add(trace)
      @queue.push(trace)
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
      if size > 10
        Instana.logger.debug "Trace queue is #{size}"
      end

      spans = []
      until @queue.empty? do
        set = @queue.pop(true)
        set.each do |s|
          spans << s.raw
        end
      end
      ::Instana.agent.report_traces(spans)
    end
  end
end
