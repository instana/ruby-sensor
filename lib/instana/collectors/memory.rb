module Instana
  module Collector
    class Memory
      attr_accessor :last_mem_size
      attr_accessor :last_mem_reported

      def initialize
        @first_run = true
        @last_mem_size = 0
      end

      ##
      # collect
      #
      # To collect process memory usage.
      #
      def collect
        this_mem = {}
        mem = GetProcessMem.new(Process.pid)

        unless mem.kb == @last_mem_size
          this_mem[:size_kb] = mem.kb
          @last_mem_size = mem.kb
        end

        ::Instana.agent.payload[:memory] = this_mem
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
