# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'singleton'

module Instana
  module Backend
    # Keeps track of garbage collector related metrics
    # @since 1.197.0
    class GCSnapshot
      include Singleton

      def initialize
        ::GC::Profiler.enable

        @last_major_count = 0
        @last_minor_count = 0
      end

      def report
        stats = ::GC.stat
        total_time = ::GC::Profiler.total_time * 1000

        ::GC::Profiler.clear

        payload = {
          totalTime: total_time,
          heap_live: stats[:heap_live_slots] || stats[:heap_live_num],
          heap_free: stats[:heap_free_slots] || stats[:heap_free_num],
          minorGcs: stats[:minor_gc_count] - @last_minor_count,
          majorGcs: stats[:major_gc_count] - @last_major_count
        }

        @last_major_count = stats[:major_gc_count]
        @last_minor_count = stats[:minor_gc_count]

        payload
      end
    end
  end
end
