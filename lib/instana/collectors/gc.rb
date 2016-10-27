module Instana
  module Collector
    class GC

      def initialize
        @first_run = true
        @last_minor_count = 0
        @last_major_count = 0
        @last_total_time = 0
        @last_count = {}
        @last_report = {}
        ::Instana.agent.payload[:gc] = { :minorGcs => 0, :majorGcs => 0, :totalTime => 0  }
        ::GC::Profiler.enable
      end

      ##
      # collect
      #
      # To collect garbage collector related metrics.
      #
      # FIXME: Add version specific KVs to GC.stat calls
      #
      def collect
        this_gc = {}

        stats = ::GC.stat
        cur_minor_count = stats[:minor_gc_count]
        cur_major_count = stats[:major_gc_count]
        cur_total_time = ::GC::Profiler.total_time

        # If this is the first run, just set these values
        # so zero will be reported for the first run
        if @first_run
          @last_minor_count = cur_minor_count
          @last_major_count = cur_major_count
          @last_total_time  = cur_total_time
          @first_run = false
          return
        end

        minor_diff = cur_minor_count - @last_minor_count
        major_diff = cur_major_count - @last_major_count
        total_time_diff = cur_total_time - @last_total_time

        # Report _only_ when the value has changed from
        # the last time around the carousel
        if minor_diff == @last_report[:minorGcs]
          this_gc.delete(:minorGcs)
        else
          @last_report[:minorGcs] = minor_diff
          this_gc[:minorGcs] = minor_diff
        end

        if major_diff == @last_report[:majorGcs]
          this_gc.delete(:majorGcs)
        else
          @last_report[:majorGcs] = major_diff
          this_gc[:majorGcs] = major_diff
        end

        if total_time_diff == @last_report[:totalTime]
          this_gc.delete(:totalTime)
        else
          @last_report[:totalTime] = total_time_diff
          this_gc[:totalTime] = total_time_diff
        end

        if this_gc.empty?
          ::Instana.agent.payload.delete(:gc)
        else
          ::Instana.agent.payload[:gc] = this_gc
        end

        @last_minor_count = cur_minor_count
        @last_major_count = cur_major_count
        @last_total_time  = cur_total_time
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
