module Instana
  module Collector
    class GC

      def initialize
        ::Instana.agent.payload[:gc] = @last_report = { :minorGcs => 0, :majorGcs => 0, :totalTime => 0  }
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
        this_gc = {}
        stats = ::GC.stat

        # Time spent in GC.  Report in milliseconds
        this_gc[:totalTime] = ::GC::Profiler.total_time * 1000
        ::GC::Profiler.clear

        # GC runs.  Calculate how many have occurred since the last call
        this_gc[:minorGcs]  = stats[:minor_gc_count] - @last_minor_count
        this_gc[:majorGcs]  = stats[:major_gc_count] - @last_major_count

        # Store these counts so that we have something to compare to next
        # time around.
        @last_major_count = stats[:major_gc_count]
        @last_minor_count = stats[:minor_gc_count]

        # GC Heap
        this_gc[:heap_live] = stats[:heap_live_slot] || stats[:heap_live_slots] || stats[:heap_live_num]
        this_gc[:heap_free] = stats[:heap_free_slot] || stats[:heap_free_slots] || stats[:heap_free_num]

        # Total allocated objects
        this_gc[:total_allocated_objects] = stats[:total_allocated_object] || stats[:total_allocated_objects]

        ::Instana.agent.payload.delete(:gc)
        this_gc = ::Instana::Util.enforce_deltas(this_gc, @last_report)
        ::Instana.agent.payload[:gc] = this_gc unless this_gc.empty?
        @last_report.merge!(this_gc)
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:gc][:enabled]
  ::Instana.collectors << ::Instana::Collector::GC.new
end
