# (c) Copyright IBM Corp. 2025

module Instana
  module Instrumentation
    module BunnyProducer
      def publish(payload, options = {})
        if ::Instana.tracer.tracing?
          exchange_name = name.empty? ? 'default' : name
          routing_key = options[:routing_key] || ''

          kvs = {
            rabbitmq: {
              sort: 'publish',
              address: channel.connection.host,
              key: routing_key,
              exchange: exchange_name
            }
          }

          ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do |span|
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
      rescue => e
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        raise
      end
    end

    module BunnyConsumer
      def pop(options = {})
        delivery_info, properties, payload = super(options)

        return [delivery_info, properties, payload] unless delivery_info

        trace_rabbitmq_consume(delivery_info, properties) do
          [delivery_info, properties, payload]
        end
      rescue => e
        log_error(e)
        raise
      end

      def subscribe(options = {}, &block)
        if block_given?
          wrapped_block = lambda do |delivery_info, properties, payload|
            trace_rabbitmq_consume(delivery_info, properties) do
              block.call(delivery_info, properties, payload)
            end
          end

          super(options, &wrapped_block)
        else
          super(options, &block)
        end
      rescue => e
        log_error(e)
        raise
      end

      private

      def trace_rabbitmq_consume(delivery_info, properties, &block)
        return yield unless ::Instana.tracer.tracing? || extract_context_from_headers(properties)

        kvs = build_consume_attributes(delivery_info)
        context = extract_context_from_headers(properties)

        if context[:trace_id]
          trace_with_context(context, kvs, &block)
        else
          ::Instana.tracer.in_span(:rabbitmq, attributes: kvs, &block)
        end
      end

      def build_consume_attributes(delivery_info)
        queue_name = name
        exchange_name = delivery_info.exchange.empty? ? 'default' : delivery_info.exchange

        {
          rabbitmq: {
            sort: 'consume',
            address: channel.connection.host,
            queue: queue_name,
            exchange: exchange_name,
            key: delivery_info.routing_key
          }
        }
      end

      def trace_with_context(context, kvs, &block)
        instana_context = ::Instana::SpanContext.new(
          trace_id: context[:trace_id],
          span_id: context[:span_id],
          level: context[:level]
        )
        span = OpenTelemetry::Trace.non_recording_span(instana_context)

        Trace.with_span(span) do
          ::Instana.tracer.in_span(:rabbitmq, attributes: kvs, &block)
        end
      end

      def extract_context_from_headers(properties)
        return {} unless properties && properties.headers

        headers = properties.headers
        {
          trace_id: headers['X-Instana-T'],
          span_id: headers['X-Instana-S'],
          level: headers['X-Instana-L']&.to_i
        }.reject { |_, v| v.nil? }
      end

      def log_error(error)
        # Log errors on to console if INSTANA_DEBUG is enabled
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{error.message}" }
      end
    end
  end
end
