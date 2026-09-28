# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/messaging'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      # Converter for messaging spans to OTLP format
      class MessagingConverter < BaseConverter
        # Build OTel-compliant span name for messaging spans
        #
        # Formula per SPAN_NAME_PATTERNS.txt Section 3 (bunny/AMQP / Kafka):
        #   RabbitMQ publish → "{exchange} publish"   (or "{queue} publish" when no exchange)
        #   RabbitMQ receive → "{queue} receive"
        #   Kafka            → "{service} {access}"    (e.g., "orders send")
        #
        # @return [String] The span name
        def span_name
          if (rabbitmq_data = span[:data]&.[](:rabbitmq))
            rabbitmq_span_name(rabbitmq_data)
          elsif (kafka_data = span[:data]&.[](:kafka))
            kafka_span_name(kafka_data)
          else
            super
          end
        end

        def convert_attributes
          attributes = {}

          convert_rabbitmq_attributes(attributes, span[:data]&.[](:rabbitmq))
          convert_kafka_attributes(attributes, span[:data]&.[](:kafka))

          attributes
        end

        private

        def rabbitmq_span_name(rabbitmq_data)
          sort = rabbitmq_data[:sort].to_s

          if sort == 'publish'
            dest = rabbitmq_data[:exchange].to_s.strip
            dest = rabbitmq_data[:queue].to_s.strip if dest.empty?
            dest.empty? ? 'publish' : "#{dest} publish"
          else
            queue = rabbitmq_data[:queue].to_s.strip
            queue.empty? ? 'receive' : "#{queue} receive"
          end
        end

        def kafka_span_name(kafka_data)
          service = kafka_data[:service].to_s.strip
          access = kafka_data[:access].to_s.strip
          parts = [service, access].reject(&:empty?)
          parts.empty? ? 'kafka' : parts.join(' ')
        end

        def convert_rabbitmq_attributes(attributes, rabbitmq_data)
          return unless rabbitmq_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'rabbitmq')
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME,
                        rabbitmq_destination_name(rabbitmq_data))
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_RABBITMQ_DESTINATION_ROUTING_KEY, rabbitmq_data[:key])
          add_attribute(attributes, 'messaging.rabbitmq.queue', rabbitmq_data[:queue])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(rabbitmq_data[:address]))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(rabbitmq_data[:address]))
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_MESSAGE_BODY_SIZE, rabbitmq_data[:size])

          operation = rabbitmq_data[:sort] == 'publish' ? 'send' : 'receive'
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_NAME, rabbitmq_data[:sort])
        end

        def convert_kafka_attributes(attributes, kafka_data)
          return unless kafka_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'kafka')
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, kafka_data[:service])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_NAME, kafka_data[:access])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, kafka_data[:access])
        end

        def extract_host(address)
          return nil unless address

          address.to_s.split(':').first
        end

        def extract_port(address)
          return nil unless address

          port = address.to_s.split(':').last
          port.to_i if port =~ /^\d+$/
        end

        # Build the composite destination name per spec:
        #   Producer (publish): "{exchange}:{key}"  — omit absent parts
        #   Consumer (receive): "{exchange}:{key}:{queue}" — omit absent; deduplicate key==queue
        #
        # @param data [Hash] rabbitmq span data
        # @return [String, nil]
        def rabbitmq_destination_name(data)
          exchange = data[:exchange].to_s.strip
          key      = data[:key].to_s.strip
          queue    = data[:queue].to_s.strip
          sort     = data[:sort].to_s

          if sort == 'publish'
            parts = [exchange, key].reject(&:empty?)
          else
            # Consumer: exchange:key:queue, dedup key==queue
            parts = [exchange, key]
            parts << queue unless queue.empty? || queue == key
            parts = parts.reject(&:empty?)
          end
          parts.empty? ? nil : parts.join(':')
        end
      end
    end
  end
end
