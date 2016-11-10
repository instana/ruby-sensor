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
    def send
      return if @queue.empty?
    end
  end
end
