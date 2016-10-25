require 'net/http'
require 'uri'
require 'json'
require 'sys/proctable'
include Sys

module Instana
  module Collector
    class Heap
      ##
      # collect
      #
      # To collect heap related metrics.
      #
      # FIXME: Add version specific KVs to GC.stat calls
      # TODO: Delta only reporting
      #
      def collect
        heap = {}
        heap[:current]   = ::GC.stat[:heap_live_slots]
        heap[:available] = ::GC.stat[:heap_available_slots]
        heap[:used]      = ::GC.stat[:heap_free_slots]
        heap[:physical]  = ::GC.stat[:heap_free_slots]

        Instana.agent.payload[:heapSpaces] = heap
      rescue => e
        Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:heap][:enabled]
  ::Instana.collectors << ::Instana::Collector::Heap.new
end
