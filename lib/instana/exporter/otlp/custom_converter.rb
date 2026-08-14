# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Converter for Instana SDK custom spans to OTLP format
      class CustomConverter < BaseConverter
        # Build OTel-compliant span name for custom (SDK) spans
        #
        # Formula per SPAN_NAME_PATTERNS.txt Section 7:
        #   Use the user-supplied sdk[:name] when available, otherwise fall back
        #   to the internal span type key (span[:n]).
        #
        # @return [String] The span name
        def span_name
          sdk_name = span[:data]&.[](:sdk)&.[](:name).to_s.strip
          sdk_name.empty? ? super : sdk_name
        end

        def convert_attributes
          attributes = {}
          sdk_data = span[:data]&.[](:sdk) || {}

          # Add standard Instana attributes
          add_attribute(attributes, 'instana.span.type', 'custom')
          add_attribute(attributes, 'instana.sdk.name', sdk_data[:name] || span[:n])
          add_attribute(attributes, 'instana.sdk.type', sdk_data[:type])

          # Add tags directly
          tags = sdk_data.dig(:custom, :tags) || {}
          tags.each do |key, value|
            attributes[key] = value
          end

          attributes
        end
      end
    end
  end
end
