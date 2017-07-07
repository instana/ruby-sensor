module Instana
  module Instrumentation
    class SidekiqClient
      def call(worker_class, msg, queue, redis_pool)
        kv_payload = { :sidekiqclient => {} }
        kv_payload[:sidekiqclient][:queue] = queue
        kv_payload[:sidekiqclient][:job] = worker_class
        kv_payload[:sidekiqclient][:retry] = msg['retry']
        ::Instana.tracer.log_entry(:sidekiqclient, kv_payload)

        context = ::Instana.tracer.context
        if context
          msg['X-Instana-T'] = context.trace_id_header
          msg['X-Instana-S'] = context.span_id_header
        end

        result = yield

        kv_payload[:sidekiqclient][:job_id] = result['jid']
        result
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:sidekiqclient, kv_payload)
      end
    end
  end
end

if defined?(::Sidekiq) && ::Instana.config[:sidekiq_client][:enabled]
  ::Sidekiq.configure_client do |cfg|
    cfg.client_middleware do |chain|
      ::Instana.logger.warn "Instrumenting Sidekiq client"
      chain.add ::Instana::Instrumentation::SidekiqClient
    end
  end
end
