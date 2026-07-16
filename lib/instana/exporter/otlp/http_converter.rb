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
          add_attribute(attributes, OpenTelemetry::SemConv::URL::URL_QUERY, http_data[:params])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(http_data[:host]))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(http_data[:host], http_data[:url]))
          add_attribute(attributes, OpenTelemetry::SemConv::URL::URL_SCHEME, extract_scheme(http_data[:url]))
          add_attribute(attributes, OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE, http_data[:status])
          add_attribute(attributes, OpenTelemetry::SemConv::USER_AGENT::USER_AGENT_ORIGINAL, http_data.dig(:header, 'user-agent'))

          add_protocol_attributes(attributes, http_data[:protocol])

          attributes
        end

        # Build OTel-compliant span status, treating EXIT spans with 4xx as ERROR
        #
        # @param error_count [Integer] Span error count
        # @param error_msg   [String, nil] Pre-extracted error message
        # @return [Status]
        def build_status(error_count, error_msg)
          return super unless error_count.zero?

          http_data = span[:data]&.[](:http) || {}
          status_code = http_data[:status].to_i

          if convert_span_kind == :client && status_code >= 400 && status_code < 500
            Status.new(OpenTelemetry::Trace::Status::ERROR, '')
          else
            super
          end
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

        private

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

        # Extract the host part from a "host:port" string or bare hostname
        # @param host_str [String, nil] e.g. "api.example.com:8080" or "api.example.com"
        # @return [String, nil]
        def extract_host(host_str)
          return nil unless host_str

          part = host_str.to_s.split(':').first
          (part && !part.empty?) ? part : host_str
        end

        # Extract the port from a "host:port" string, falling back to the URL port
        # @param host_str [String, nil] e.g. "api.example.com:8080"
        # @param url      [String, nil] full URL as fallback
        # @return [Integer, nil]
        def extract_port(host_str, url)
          if host_str&.include?(':')
            port = host_str.split(':').last
            return port.to_i unless port.nil? || port.empty?
          end

          return nil unless url

          uri = URI.parse(url)
          uri.port
        rescue URI::InvalidURIError
          nil
        end

        # Emit network.protocol.name and network.protocol.version from e.g. "HTTP/1.1"
        # @param attributes [Hash]
        # @param protocol   [String, nil] e.g. "HTTP/1.1" or "h2"
        def add_protocol_attributes(attributes, protocol)
          return unless protocol

          parts = protocol.to_s.split('/', 2)
          name    = parts[0].downcase
          version = parts[1]

          add_attribute(attributes, 'network.protocol.name', name)
          add_attribute(attributes, 'network.protocol.version', version)
        end
      end
    end
  end
end
