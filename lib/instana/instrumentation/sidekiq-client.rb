# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

module Instana
  module Instrumentation
    class SidekiqClient
      def call(worker_class, msg, queue, _redis_pool)
        kvs = { :'sidekiq-client' => {} }
        kvs[:'sidekiq-client'][:queue] = queue
        kvs[:'sidekiq-client'][:job] = worker_class.to_s
        kvs[:'sidekiq-client'][:retry] = msg['retry'].to_s

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
          kvs[:'sidekiq-client'][:'redis-url'] = "#{host}:#{port}"
        end

        Instana.tracer.in_span(:'sidekiq-client', attributes: kvs) do |span|
          context = ::Instana.tracer.context
          if context
            msg['X-Instana-T'] = context.trace_id_header
            msg['X-Instana-S'] = context.span_id_header
          end

          result = yield

          if result && result['jid']
            span.set_tag(:'sidekiq-client', { job_id: result['jid'] })
          end

          result
        rescue => e
          span.record_exception(e)
          raise
        end
      end
    end
  end
end
