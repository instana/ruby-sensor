module Instana
  module Collector
    class Thread
      attr_accessor :last_count

      def initialize
        @last_count = 0
        ::Instana.agent.payload[:thread] = { :count => 0 }
      end

      ##
      # collect
      #
      # To collect thread count
      #
      def collect
        this_count = ::Thread.list.count

        unless this_count == @last_count
          ::Instana.agent.payload[:thread] = { :count => this_count }
        end
        @last_count = this_count
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
