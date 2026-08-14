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
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::GRAPHQL::GRAPHQL_DOCUMENT, format_fields(graphql_data[:fields]))

          # Add arguments as custom attribute
          add_attribute(attributes, 'graphql.arguments', format_arguments(graphql_data[:arguments])) if graphql_data[:arguments]

          attributes
        end

        private

        def format_fields(fields)
          return nil unless fields

          fields.map { |obj, flds| "#{obj} { #{flds.join(', ')} }" }.join(', ')
        end

        def format_arguments(arguments)
          return nil unless arguments

          arguments.map { |obj, args| "#{obj}(#{args.join(', ')})" }.join(', ')
        end
      end
    end
  end
end
