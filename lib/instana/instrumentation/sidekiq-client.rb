# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    class SidekiqClient
      def self.redis_url
        Sidekiq.redis_pool.with do |client|
          host, port =
            case
            when client.respond_to?(:config)
              [client.config.host, client.config.port]
            when client.respond_to?(:connection)
              [client.connection[:host], client.connection[:port]]
            else
              [client.client.options[:host], client.client.options[:port]]
            end
          return "#{host}:#{port}"
        end
      end

      def call(worker_class, msg, queue, _redis_pool)
        kv_payload = { :'sidekiq-client' => {} }
        kv_payload[:'sidekiq-client'][:queue] = queue
        kv_payload[:'sidekiq-client'][:job] = worker_class.to_s
        kv_payload[:'sidekiq-client'][:retry] = msg['retry'].to_s
        ::Instana.tracer.log_entry(:'sidekiq-client', kv_payload)

        # Temporary until we move connection collection to redis
        # instrumentation
        kv_payload[:'sidekiq-client'][:'redis-url'] = SidekiqClient.redis_url

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
