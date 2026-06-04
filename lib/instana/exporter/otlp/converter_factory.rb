# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require_relative 'http_converter'
require_relative 'database_converter'
require_relative 'messaging_converter'
require_relative 'rpc_converter'
require_relative 'custom_converter'
require_relative 'internal_converter'
require_relative '../../trace/span_kind'

module Instana
  module Exporter
    module Otlp
      # Factory class for creating appropriate OTLP span converters
      # based on span type
      class ConverterFactory
        # Span type constants
        SPAN_TYPES = {
          http: 'http',
          database: 'database',
          messaging: 'messaging',
          rpc: 'rpc',
          internal: 'internal',
          custom: 'custom'
        }.freeze

        class << self
          # Create a converter for the given span
          # @param span [Instana::Trace::Span] The span to convert
          # @return [BaseConverter] An instance of the appropriate converter
          def create(span)
            span_type = determine_span_type(span)
            converter_class = get_converter_class(span_type)

            converter_class.new(span)
          end

          private

          # Determine the type of span based on its attributes
          # @param span [Instana::Trace::Span] The span to analyze
          # @return [String] The span type
          def determine_span_type(span)
            return SPAN_TYPES[:http] if http_span?(span)
            return SPAN_TYPES[:database] if database_span?(span)
            return SPAN_TYPES[:messaging] if messaging_span?(span)
            return SPAN_TYPES[:rpc] if rpc_span?(span)
            return SPAN_TYPES[:custom] if custom_span?(span)

            SPAN_TYPES[:internal]
          end

          # Get the appropriate converter class for the span type
          # @param span_type [String] The type of span
          # @return [Class] The converter class
          def get_converter_class(span_type)
            class_name = "#{span_type.capitalize}Converter"

            begin
              const_get("Instana::Exporter::Otlp::#{class_name}")
            rescue NameError
              # Fall back to base converter if specific converter not found
              BaseConverter
            end
          end

          # Check if span is an HTTP span
          # Uses the HTTP_SPANS constant to identify HTTP spans
          def http_span?(span)
            Instana::SpanKind::HTTP_SPANS.include?(span.name&.to_sym)
          end

          # Check if span is a database span
          # Instana native spans always have a name, so we only check the name
          def database_span?(span)
            span.name&.match?(/sql|database|query|activerecord|sequel|mongo|redis|dalli/i)
          end

          # Check if span is a messaging span
          # Instana native spans always have a name, so we only check the name
          def messaging_span?(span)
            span.name&.match?(/kafka|rabbitmq|sqs|sns|message|bunny|shoryuken/i)
          end

          # Check if span is an RPC span
          # Instana native spans always have a name, so we only check the name
          def rpc_span?(span)
            span.name&.match?(/grpc|rpc/i)
          end

          # Check if span is a custom span
          # Instana native spans always have a name, so we only check the name
          def custom_span?(span)
            span.name&.match?(/custom|sdk/i)
          end
        end
      end
    end
  end
end
