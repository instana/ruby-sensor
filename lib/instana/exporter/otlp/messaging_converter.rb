# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Converter for messaging spans to OTLP format
      # Handles conversion of messaging-related spans (Kafka, RabbitMQ, SQS, etc.)
      # NOTE: This converter is a placeholder for future implementation
      class MessagingConverter < BaseConverter
        # Convert messaging span to OTLP format
        # @return [Hash] Converted messaging span data in OTLP format
        def convert
          # For now, return base attributes only
          # Messaging-specific attributes will be added in a future phase
          super
        end
      end
    end
  end
end
