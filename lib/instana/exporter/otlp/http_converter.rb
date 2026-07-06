# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/http'
require 'opentelemetry/semconv/url'
require 'opentelemetry/semconv/server'
require 'opentelemetry/semconv/user_agent'

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

          add_attribute(attributes, OpenTelemetry::SemConv::HTTP::HTTP_REQUEST_METHOD, http_data[:method])
          add_attribute(attributes, OpenTelemetry::SemConv::URL::URL_FULL, http_data[:url])
          add_attribute(attributes, OpenTelemetry::SemConv::URL::URL_PATH, http_data[:path])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, http_data[:host])
          add_attribute(attributes, OpenTelemetry::SemConv::URL::URL_SCHEME, extract_scheme(http_data[:url]))
          add_attribute(attributes, OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE, http_data[:status])
          add_attribute(attributes, OpenTelemetry::SemConv::USER_AGENT::USER_AGENT_ORIGINAL, http_data.dig(:header, 'user-agent'))

          attributes
        end

        # Build OTel-compliant span name for HTTP spans
        #
        # Convention (stable): "{METHOD}" or "{METHOD} {url.template/path}"
        # Falls back to "HTTP" when no method is present.
        #
        # @return [String] The span name
        def span_name
          http_data = span[:data]&.[](:http) || {}
          method = http_data[:method].to_s.upcase
          method = 'HTTP' if method.empty?

          path = http_data[:path].to_s.strip
          path.empty? ? method : "#{method} #{path}"
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
