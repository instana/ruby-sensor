module Instana
  module Collector
    class GC
      attr_accessor :last_minor_count
      attr_accessor :last_major_count

      def initialize
        @last_minor_count = 0
        @last_major_count = 0
        ::Instana.agent.payload[:gc] = { :minorGcs => 0, :majorGcs => 0 }
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

        minor_diff = cur_minor_count - @last_minor_count
        major_diff = cur_major_count - @last_major_count

        # Report _only_ when the value has changed from
        # the last time around the carousel
        if minor_diff == last_gc[:minorGcs]
          this_gc.delete(:minorGcs)
        else
          this_gc[:minorGcs] = minor_diff
        end

        if major_diff == last_gc[:majorGcs]
          this_gc.delete(:majorGcs)
        else
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
