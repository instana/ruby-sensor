# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semantic_conventions'

module Instana
  module Exporter
    module Otlp
      # Converter for HTTP spans to OTLP format
      # Handles conversion of HTTP-related spans with specific attributes
      class HttpConverter < BaseConverter
        # Convert HTTP span to OTLP format
        # @return [Hash] Converted HTTP span data in OTLP format
        def convert
          base_data = extract_common_attributes

          # Add HTTP-specific attributes to the attributes array
          http_attrs = extract_http_attributes
          base_data[:attributes].concat(http_attrs) if http_attrs.any?

          base_data
        end

        private

        # Extract HTTP-specific attributes in OTLP format
        # @return [Array<Hash>] Array of OTLP key-value pairs for HTTP attributes
        def extract_http_attributes
          attributes = []
          http_data = span[:data]&.[](:http) || {}

          # Use semantic conventions constants for HTTP attributes
          # Only add attributes that are actually present in Instana spans
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD, http_data[:method])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_URL, http_data[:url])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET, http_data[:path])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_HOST, http_data[:host])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_SCHEME, extract_scheme(http_data[:url]))
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE, http_data[:status])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_USER_AGENT, http_data.dig(:header, 'user-agent'))
          # NOTE: request_content_length and response_content_length are not captured by Instana instrumentation

          attributes
        end

        # Extract scheme from URL
        # @param url [String] The URL
        # @return [String, nil] The scheme (http or https)
        def extract_scheme(url)
          return nil unless url

          uri = URI.parse(url)
          uri.scheme
        rescue URI::InvalidURIError
          nil
        end

        # Add an attribute to the attributes array if value is present
        # @param attributes [Array<Hash>] The attributes array
        # @param key [String] The attribute key
        # @param value [Object] The attribute value
        def add_attribute(attributes, key, value)
          return unless value

          attributes << {
            key: key,
            value: convert_attribute_value(value)
          }
        end
      end
    end
  end
end
