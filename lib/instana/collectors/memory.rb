require 'get_process_mem'

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
        mem = ::GetProcessMem.new(Process.pid)

        if (mem.kb == @last_mem_size) && (::Instana.agent.last_entity_response == 200)
          # If the value hasn't changed and the last report was successful, send nothing.
          ::Instana.agent.payload.delete(:memory)
        else
          this_mem = {}
          this_mem[:rss_size] = mem.kb
          @last_mem_size = mem.kb
          ::Instana.agent.payload[:memory] = this_mem
        end
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
