# (c) Copyright IBM Corp. 2025

module Instana
  module Instrumentation
    module BunnyProducer
      def publish(payload, options = {})
        current_span = nil
        if ::Instana.tracer.tracing?
          exchange_name = name.empty? ? 'default' : name
          routing_key = options[:routing_key] || ''

          kvs = {
            rabbitmq: {
              sort: 'entry',
              address: channel.connection.host,
              key: routing_key,
              exchange: exchange_name
            }
          }

          ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do |span|
            current_span = span
            # Inject trace context into message headers
            options[:headers] ||= {}
            options[:headers]['X-Instana-T'] = span.context.trace_id
            options[:headers]['X-Instana-S'] = span.context.span_id
            options[:headers]['X-Instana-L'] = span.context.level.to_s

            super(payload, options)
          end
        else
          super(payload, options)
        end
      rescue
        current_span&.record_exception(e)
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        raise
      end
    end
  end
end
