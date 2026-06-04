# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Stub converter for custom spans to OTLP format
      # This is a placeholder implementation for custom application-specific spans
      # TODO: Implement full custom span conversion logic
      class CustomConverter < BaseConverter
        # Convert custom span to OTLP format
        # @return [Hash] Converted custom span data in OTLP format
        def convert
          # Stub implementation - returns base attributes only
          super
        end
      end
    end
  end
end
