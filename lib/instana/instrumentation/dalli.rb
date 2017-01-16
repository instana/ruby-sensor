module Instana
  module Instrumentation
    module Dalli
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :perform)
        ::Instana::Util.method_alias(klass, :get_multi)
      end

      def perform_with_instana(*args, &blk)
        ::Instana.tracer.log_entry(:memcache, { :memcache => { :command => args[0] } })
        perform_without_instana(*args, &blk)
      rescue => e
        ::Instana.tracer.log_error(e)
      ensure
        ::Instana.tracer.log_exit(:memcache)
      end

      def get_multi_with_instana(*keys)
      end
    end
  end
end

if defined?(::Dalli) && ::Instana.config[:dalli][:enabled]
  ::Instana.logger.warn "Instrumenting Dalli"
  ::Dalli::Client.send(:include, ::Instana::Instrumentation::Dalli)
end
