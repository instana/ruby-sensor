# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    module Dalli
      def perform(*args, &blk)
        if !::Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:memcache)
          do_skip = true
          return super(*args, &blk)
        end

        op, key, *_opts = args

        entry_payload = { :memcache => {} }
        entry_payload[:memcache][:namespace] = @options[:namespace] if @options.key?(:namespace)
        entry_payload[:memcache][:command] = op
        entry_payload[:memcache][:key] = key

        ::Instana.tracer.log_entry(:memcache, entry_payload)
        exit_payload = { :memcache => {} }

        result = super(*args, &blk)

        if op == :get
          exit_payload[:memcache][:hit] = result ? 1 : 0
        end
        result
      rescue => e
        exit_payload[:memcache][:error] = e.message rescue nil
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:memcache, exit_payload) unless do_skip
      end

      def get_multi(*keys)
        entry_payload = { :memcache => {} }
        entry_payload[:memcache][:namespace] = @options[:namespace] if @options.key?(:namespace)
        entry_payload[:memcache][:command] = :get_multi
        entry_payload[:memcache][:keys] = keys.flatten.join(", ")

        ::Instana.tracer.log_entry(:memcache, entry_payload)
        exit_payload = { :memcache => {} }

        result = super(*keys)

        exit_payload[:memcache][:hits] = result.length
        result
      rescue => e
        exit_payload[:memcache][:error] = e.message rescue nil
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:memcache, exit_payload)
      end
    end

    module DalliServer
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :request)
      end

      def request(op, *args, **kwargs)
        if ::Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:memcache)
          info_payload = { :memcache => {} }
          info_payload[:memcache][:server] = "#{@hostname}:#{@port}"
          ::Instana.tracer.log_info(info_payload)
        end
        super(op, *args, **kwargs)
      end
    end
  end
end
