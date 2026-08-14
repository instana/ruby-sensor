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
        # Build OTel-compliant span name for messaging (RabbitMQ) spans
        #
        # Formula per SPAN_NAME_PATTERNS.txt Section 3 (bunny/AMQP):
        #   publish → "{exchange} publish"   (or "{queue} publish" when no exchange)
        #   receive → "{queue} receive"
        #
        # @return [String] The span name
        def span_name
          rabbitmq_data = span[:data]&.[](:rabbitmq) || {}
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

        def convert_attributes
          attributes = {}

          rabbitmq_data = span[:data]&.[](:rabbitmq)
          if rabbitmq_data
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'rabbitmq')
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME,
                          rabbitmq_destination_name(rabbitmq_data))
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_RABBITMQ_DESTINATION_ROUTING_KEY, rabbitmq_data[:key])
            add_attribute(attributes, 'messaging.rabbitmq.queue', rabbitmq_data[:queue])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rabbitmq_data[:address])

            operation = rabbitmq_data[:sort] == 'publish' ? 'send' : 'receive'
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation)
          end

          attributes
        end

        private

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
