module Instana
  module Instrumentation
    module Dalli
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :perform)
        ::Instana::Util.method_alias(klass, :get_multi)
      end

      def perform_with_instana(*args, &blk)
        if !::Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:memcache)
          return perform_without_instana(*args, &blk)
        end

        op, key, *_opts = args

        entry_payload = { :memcache => {} }
        entry_payload[:memcache][:namespace] = @options[:namespace] if @options.key?(:namespace)
        entry_payload[:memcache][:command] = op
        entry_payload[:memcache][:key] = key

        ::Instana.tracer.log_entry(:memcache, entry_payload)
        result = perform_without_instana(*args, &blk)

        kv_payload = { :memcache => {}}
        kv_payload[:memcache][:hit] = result ? true : false
        result
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:memcache, kv_payload)
      end

      def get_multi_with_instana(*keys)
        entry_payload = { :memcache => {} }
        entry_payload[:memcache][:namespace] = @options[:namespace] if @options.key?(:namespace)
        entry_payload[:memcache][:command] = :get_multi
        entry_payload[:memcache][:keys] = keys.flatten

        ::Instana.tracer.log_entry(:memcache, entry_payload)
        result = get_multi_without_instana(*keys)

        kv_payload = {}
        kv_payload[:hit_count] = result.length
        result
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:memcache, kv_payload)
      end
    end

    module DalliServer
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :request)
      end

      def request_with_instana(op, *args)
        if ::Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:memcache)
          info_payload = { :memcache => {} }
          info_payload[:memcache][:server] = "#{@hostname}:#{@port}"
          ::Instana.tracer.log_info(info_payload)
        end
        request_without_instana(op, *args)
      end
    end
  end
end

if defined?(::Dalli) && ::Instana.config[:dalli][:enabled]
  ::Instana.logger.warn "Instrumenting Dalli"
  ::Dalli::Client.send(:include, ::Instana::Instrumentation::Dalli)
  ::Dalli::Server.send(:include, ::Instana::Instrumentation::DalliServer)
end
