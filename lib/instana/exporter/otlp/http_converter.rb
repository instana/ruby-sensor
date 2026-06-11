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

        # Extract HTTP-specific attributes as plain key/value pairs
        # @return [Hash] HTTP attributes
        def convert_attributes
          attributes = {}
          http_data = span[:data]&.[](:http) || {}

          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD, http_data[:method])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_URL, http_data[:url])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET, http_data[:path])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_HOST, http_data[:host])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_SCHEME, extract_scheme(http_data[:url]))
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE, http_data[:status])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::HTTP_USER_AGENT, http_data.dig(:header, 'user-agent'))

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
      end
    end
  end
end
