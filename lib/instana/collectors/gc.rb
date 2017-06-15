module Instana
  module Collectors
    class GC
      attr_accessor :payload_key

      def initialize
        @payload_key = :gc
        @this_gc = {}
        @last_major_count = 0
        @last_minor_count = 0
        ::GC::Profiler.enable
      end

      ##
      # collect
      #
      # To collect garbage collector related metrics.
      #
      def collect
        @this_gc.clear
        stats = ::GC.stat

        # Time spent in GC.  Report in milliseconds
        @this_gc[:totalTime] = ::GC::Profiler.total_time * 1000
        ::GC::Profiler.clear

        # GC metrics only available on newer Ruby versions
        if RUBY_VERSION >= '2.1'
          # GC runs.  Calculate how many have occurred since the last call
          @this_gc[:minorGcs] = stats[:minor_gc_count] - @last_minor_count
          @this_gc[:majorGcs] = stats[:major_gc_count] - @last_major_count

          # Store these counts so that we have something to compare to next
          # time around.
          @last_major_count = stats[:major_gc_count]
          @last_minor_count = stats[:minor_gc_count]
        end

        # GC Heap
        @this_gc[:heap_live] = stats[:heap_live_slot] || stats[:heap_live_slots] || stats[:heap_live_num]
        @this_gc[:heap_free] = stats[:heap_free_slot] || stats[:heap_free_slots] || stats[:heap_free_num]
        @this_gc
      rescue => e
        ::Instana.logger.info "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:gc][:enabled]
  ::Instana.collector.register(::Instana::Collectors::GC)
end
