# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'get_process_mem'

module Instana
  module Collectors
    class Memory
      attr_accessor :payload_key

      def initialize
        @payload_key = :memory
        @this_mem = {}
      end

      ##
      # collect
      #
      # To collect process memory usage.
      #
      # @return [Hash] a collection of metrics (if any)
      #
      def collect
        @this_mem[:rss_size] = ::GetProcessMem.new(Process.pid).kb
        @this_mem
      rescue => e
        ::Instana.logger.info "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug { e.backtrace.join("\r\n") }
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:memory][:enabled]
  ::Instana.collector.register(::Instana::Collectors::Memory)
end
