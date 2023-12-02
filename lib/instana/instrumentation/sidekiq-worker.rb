# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    class SidekiqWorker
      def call(_worker, msg, _queue)
        kv_payload = { :'sidekiq-worker' => {} }
        kv_payload[:'sidekiq-worker'][:job_id] = msg['jid']
        kv_payload[:'sidekiq-worker'][:queue] = msg['queue']
        kv_payload[:'sidekiq-worker'][:job] = msg['class'].to_s
        kv_payload[:'sidekiq-worker'][:retry] = msg['retry'].to_s

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
                       else
                         ['Unknown', 'Unknown']
                       end
          kv_payload[:'sidekiq-worker'][:'redis-url'] = "#{host}:#{port}"
        end

        context = {}
        if msg.key?('X-Instana-T')
          trace_id = msg.delete('X-Instana-T')
          span_id = msg.delete('X-Instana-S')
          context[:trace_id] = ::Instana::Util.header_to_id(trace_id)
          context[:span_id] = ::Instana::Util.header_to_id(span_id) if span_id
        end

        ::Instana.tracer.log_start_or_continue(
          :'sidekiq-worker', kv_payload, context
        )

        yield
      rescue => e
        kv_payload[:'sidekiq-worker'][:error] = true
        ::Instana.tracer.log_info(kv_payload)
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_end(:'sidekiq-worker', {}) if ::Instana.tracer.tracing?
      end
    end
  end
end
