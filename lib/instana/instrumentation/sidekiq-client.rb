# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    class SidekiqClient
      def call(worker_class, msg, queue, _redis_pool)
        kv_payload = { :'sidekiq-client' => {} }
        kv_payload[:'sidekiq-client'][:queue] = queue
        kv_payload[:'sidekiq-client'][:job] = worker_class.to_s
        kv_payload[:'sidekiq-client'][:retry] = msg['retry'].to_s
        ::Instana.tracer.log_entry(:'sidekiq-client', kv_payload)

        # Temporary until we move connection collection to redis
        # instrumentation
        Sidekiq.redis_pool.with do |client|
          sidekiq_version = Gem::Specification.find_by_name('sidekiq').version
          host, port = if sidekiq_version >= Gem::Version.new('7.0') && client.respond_to?(:config) && client.config.respond_to?(:host) && client.config.respond_to?(:port)
                         [client.config.host, client.config.port]
                       elsif client.respond_to?(:connection)
                         [client.connection[:host], client.connection[:port]]
                       elsif client.respond_to?(:client) && client.client.respond_to?(:options)
                         [client.client.options[:host], client.client.options[:port]]
                       else # Unexpected version, continue without recording any redis-url
                         break
                       end
          kv_payload[:'sidekiq-client'][:'redis-url'] = "#{host}:#{port}"
        end

        context = ::Instana.tracer.context
        if context
          msg['X-Instana-T'] = context.trace_id_header
          msg['X-Instana-S'] = context.span_id_header
        end

        result = yield

        kv_payload[:'sidekiq-client'][:job_id] = result['jid']
        result
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:'sidekiq-client', kv_payload)
      end
    end
  end
end
