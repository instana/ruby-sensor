module Instana
  module Instrumentation
    class SidekiqWorker
      def call(_worker, msg, _queue)
        kv_payload = { :'sidekiq-worker' => {} }
        kv_payload[:'sidekiq-worker'][:job_id] = msg['jid']
        kv_payload[:'sidekiq-worker'][:queue] = msg['queue']
        kv_payload[:'sidekiq-worker'][:job] = msg['class']
        kv_payload[:'sidekiq-worker'][:retry] = msg['retry'].to_s

        # Temporary until we move connection collection to redis
        # instrumentation
        Sidekiq.redis_pool.with do |client|
          opts = client.respond_to?(:connection) ? client.connection : client.client.options
          kv_payload[:'sidekiq-worker'][:'redis-url'] = "#{opts[:host]}:#{opts[:port]}"
        end

        if ENV.key?('INSTANA_SERVICE_NAME')
          kv_payload[:service] = ENV['INSTANA_SERVICE_NAME']
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

if defined?(::Sidekiq) && ::Instana.config[:'sidekiq-worker'][:enabled]
  ::Sidekiq.configure_server do |cfg|
    cfg.server_middleware do |chain|
      ::Instana.logger.debug "Instrumenting Sidekiq worker"
      chain.add ::Instana::Instrumentation::SidekiqWorker
    end
  end
end
