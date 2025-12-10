# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    class SidekiqWorker
      def call(_worker, msg, _queue)
        kvs = { :'sidekiq-worker' => {} }
        kvs[:'sidekiq-worker'][:job_id] = msg['jid']
        kvs[:'sidekiq-worker'][:queue] = msg['queue']
        kvs[:'sidekiq-worker'][:job] = msg['class'].to_s
        kvs[:'sidekiq-worker'][:retry] = msg['retry'].to_s

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
          kvs[:'sidekiq-worker'][:'redis-url'] = "#{host}:#{port}"
        end

        trace_context = nil
        if msg.key?('X-Instana-T')
          trace_id = msg.delete('X-Instana-T')
          span_id = msg.delete('X-Instana-S')
          trace_context = ::Instana::SpanContext.new(
            trace_id: ::Instana::Util.header_to_id(trace_id),
            span_id: span_id ? ::Instana::Util.header_to_id(span_id) : nil
          )
        end

        parent_non_recording_span = OpenTelemetry::Trace.non_recording_span(trace_context) if trace_context
        Trace.with_span(parent_non_recording_span) do
          Instana.tracer.in_span(:'sidekiq-worker', attributes: kvs) do |span|
            yield
          rescue => e
            kvs[:'sidekiq-worker'][:error] = true
            span.set_tags(kvs)
            span.record_exception(e)
            raise
          end
        end
      end
    end
  end
end
