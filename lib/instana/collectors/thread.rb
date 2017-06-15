module Instana
  module Collectors
    class Thread
      attr_accessor :payload_key

      def initialize
        @payload_key = :thread
        @this_count = {}
      end

      ##
      # collect
      #
      # To collect thread count
      #
      def collect
        @this_count[:count] = ::Thread.list.count
        @this_count
      rescue => e
        ::Instana.logger.info "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:thread][:enabled]
  ::Instana.collector.register(::Instana::Collectors::Thread)
end
