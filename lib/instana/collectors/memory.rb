require 'get_process_mem'

module Instana
  module Collector
    class Memory
      attr_accessor :last_mem_size
      attr_accessor :last_mem_reported

      def initialize
        ::Instana.agent.payload[:memory] = @last_report = { :rss_size => 0  }
        @last_report = {}
      end

      ##
      # collect
      #
      # To collect process memory usage.
      #
      def collect
        this_mem = {}
        mem = ::GetProcessMem.new(Process.pid)
        this_mem[:rss_size] = mem.kb

        ::Instana.agent.payload.delete(:memory)
        this_mem = ::Instana::Util.enforce_deltas(this_mem, @last_report)
        ::Instana.agent.payload[:memory] = this_mem unless this_mem.empty?
        @last_report.merge!(this_mem)
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:memory][:enabled]
  ::Instana.collectors << ::Instana::Collector::Memory.new
end
