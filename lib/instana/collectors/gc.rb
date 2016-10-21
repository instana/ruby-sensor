module Instana
  module Collector
    class GC
      attr_accessor :last_minor_count
      attr_accessor :last_major_count
      attr_accessor :last_minor_reported
      attr_accessor :last_major_reported

      def initialize
        @first_run = true
        @last_minor_count = 0
        @last_major_count = 0
        ::Instana.agent.payload[:gc] = { :minorGcs => 0, :majorGcs => 0 }
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
        last_gc = ::Instana.agent.payload[:gc]

        stats = ::GC.stat
        cur_minor_count = stats[:minor_gc_count]
        cur_major_count = stats[:major_gc_count]

        # If this is the first run, just set these values
        # so zero will be reported for the first run
        if @first_run
          @last_minor_count = cur_minor_count
          @last_major_count = cur_major_count
          @first_run = false
          return
        end

        minor_diff = cur_minor_count - @last_minor_count
        major_diff = cur_major_count - @last_major_count

        # Report _only_ when the value has changed from
        # the last time around the carousel
        if minor_diff == @last_minor_reported
          this_gc.delete(:minorGcs)
        else
          @last_minor_reported = minor_diff
          this_gc[:minorGcs] = minor_diff
        end

        if major_diff == @last_major_reported
          this_gc.delete(:majorGcs)
        else
          @last_major_reported = major_diff
          this_gc[:majorGcs] = major_diff
        end

        ::Instana.agent.payload[:gc] = this_gc

        @last_minor_count = cur_minor_count
        @last_major_count = cur_major_count
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
