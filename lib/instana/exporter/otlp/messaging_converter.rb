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

          # RabbitMQ
          rabbitmq_data = span[:data]&.[](:rabbitmq)
          if rabbitmq_data
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'rabbitmq')
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, rabbitmq_data[:exchange])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_RABBITMQ_DESTINATION_ROUTING_KEY, rabbitmq_data[:key])
            add_attribute(attributes, 'messaging.rabbitmq.queue', rabbitmq_data[:queue])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rabbitmq_data[:address])

            operation = rabbitmq_data[:sort] == 'publish' ? 'send' : 'receive'
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation)
          end

          attributes
        end
      end
    end
  end
end
