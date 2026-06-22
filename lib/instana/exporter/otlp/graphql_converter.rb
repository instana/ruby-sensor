# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/graphql'

module Instana
  module Exporter
    module Otlp
      # Converter for GraphQL spans to OTLP format
      class GraphqlConverter < BaseConverter
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
