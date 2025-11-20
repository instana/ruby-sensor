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

          ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do
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
        # ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        # raise
      end
    end

    module BunnyConsumer
      def pop(options = {})
        delivery_info, properties, payload = super(options)

        return [delivery_info, properties, payload] unless delivery_info

        headers = properties.headers
        {
          trace_id: headers['X-Instana-T'],
          span_id: headers['X-Instana-S'],
          level: headers['X-Instana-L']&.to_i
        }.reject { |_, v| v.nil? } || {}

        if ::Instana.tracer.tracing? || headers
          queue_name = name
          exchange_name = delivery_info.exchange.empty? ? 'default' : delivery_info.exchange

          kvs = {
            rabbitmq: {
              sort: 'consume',
              address: channel.connection.host,
              queue: queue_name,
              exchange: exchange_name,
              key: delivery_info.routing_key
            }
          }

          if headers[:trace_id]
            instana_context = ::Instana::SpanContext.new(
              trace_id: headers[:trace_id],
              span_id: headers[:span_id],
              level: headers[:level]
            )
            span = OpenTelemetry::Trace.non_recording_span(instana_context)

            Trace.with_span(span) do
              ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do
                # Return the message for processing
                [delivery_info, properties, payload]
              end
            end
          else
            ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do
              [delivery_info, properties, payload]
            end
          end
        else
          [delivery_info, properties, payload]
        end
      rescue
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        raise
      end

      def subscribe(options = {}, &block)
        if block_given?
          wrapped_block = lambda do |delivery_info, properties, payload|
            headers = properties.headers
            {
              trace_id: headers['X-Instana-T'],
              span_id: headers['X-Instana-S'],
              level: headers['X-Instana-L']&.to_i
            }.reject { |_, v| v.nil? } || {}
            if ::Instana.tracer.tracing? || headers
              queue_name = name
              exchange_name = delivery_info.exchange.empty? ? 'default' : delivery_info.exchange

              kvs = {
                rabbitmq: {
                  sort: 'consume',
                  address: channel.connection.host,
                  queue: queue_name,
                  exchange: exchange_name,
                  key: delivery_info.routing_key
                }
              }

              if headers[:trace_id]
                instana_context = ::Instana::SpanContext.new(
                  trace_id: headers[:trace_id],
                  span_id: headers[:span_id],
                  level: headers[:level]
                )
                span = OpenTelemetry::Trace.non_recording_span(instana_context)

                Trace.with_span(span) do
                  ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do
                    block.call(delivery_info, properties, payload)
                  end
                end
              else
                ::Instana.tracer.in_span(:rabbitmq, attributes: kvs) do
                  block.call(delivery_info, properties, payload)
                end
              end
            else
              block.call(delivery_info, properties, payload)
            end
          end

          super(options, &wrapped_block)
        else
          super(options, &block)
        end
      rescue => e
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        raise
      end
    end
  end
end
