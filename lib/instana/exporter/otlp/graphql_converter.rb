# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/graphql'

module Instana
  module Exporter
    module Otlp
      # Converter for GraphQL spans to OTLP format
      class GraphqlConverter < BaseConverter
        # Build OTel-compliant span name for GraphQL spans
        #
        # Formula per SPAN_NAME_PATTERNS.txt Section 7 (observability):
        #   "{operationType} {operationName}"  e.g. "query MyQuery"
        #   Falls back to just "{operationType}" when no name, or "graphql" when both absent.
        #
        # @return [String] The span name
        def span_name
          gql = span[:data]&.[](:graphql) || {}
          type = gql[:operationType].to_s.strip
          name = gql[:operationName].to_s.strip

          if type.empty?
            'graphql'
          elsif name.empty?
            type
          else
            "#{type} #{name}"
          end
        end

        def convert_attributes
          attributes = {}

          graphql_data = span[:data]&.[](:graphql)
          return attributes unless graphql_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::GRAPHQL::GRAPHQL_OPERATION_NAME, graphql_data[:operationName])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::GRAPHQL::GRAPHQL_OPERATION_TYPE, graphql_data[:operationType])

          doc = graphql_data[:document] || format_fields(graphql_data[:fields])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::GRAPHQL::GRAPHQL_DOCUMENT, doc)

          if graphql_data[:errors]
            error_val = graphql_data[:errors]
            error_str = error_val.is_a?(Array) ? error_val.join(', ') : error_val.to_s
            add_attribute(attributes, 'error.type', error_str)
          end

          attributes
        end

        private

        def format_fields(fields)
          return nil unless fields

          fields.map { |obj, flds| "#{obj} { #{flds.join(', ')} }" }.join(', ')
        end
      end
    end
  end
end
