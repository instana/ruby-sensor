module Instana
  module Collector
    class Thread
      attr_accessor :last_count

      def initialize
        ::Instana.agent.payload[:thread] = @last_report = { :count => 0  }
        @last_count = 0
      end

      ##
      # collect
      #
      # To collect thread count
      #
      def collect
        this_count = {}
        this_count[:count] = ::Thread.list.count

        ::Instana.agent.payload.delete(:thread)
        this_count = ::Instana::Util.enforce_deltas(this_count, @last_report)
        ::Instana.agent.payload[:thread] = this_count unless this_count.empty?
        @last_report.merge!(this_count)
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end

# Register the metrics collector if enabled
if ::Instana.config[:metrics][:thread][:enabled]
  ::Instana.collectors << ::Instana::Collector::Thread.new
end
