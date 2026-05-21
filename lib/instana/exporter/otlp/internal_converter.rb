# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Converter for internal spans to OTLP format
      # Handles conversion of internal application spans
      class InternalConverter < BaseConverter
        # Convert internal span to OTLP format
        # @return [Hash] Converted internal span data in OTLP format
        def convert
          extract_common_attributes

          # Internal spans use the base attributes without additional specific attributes
          # but we can add any internal-specific metadata if needed
        end
      end
    end
  end
end
