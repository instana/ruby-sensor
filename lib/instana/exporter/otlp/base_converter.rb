# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Base class for all OTLP span converters
      # Provides common interface and shared functionality for converting Instana spans
      # to OTLP format
      class BaseConverter
        # @param span [Instana::Trace::Span] The span to convert
        def initialize(span)
          @span = span
        end

        # Convert the span to OTLP format
        # Must be implemented by subclasses
        # @return [Object] The converted span in OTLP format
        def convert
          raise NotImplementedError, "#{self.class} must implement #convert"
        end

        protected

        attr_reader :span

        # Extract common span attributes for OTLP
        # @return [Hash] Common attributes shared across all span types
        def extract_common_attributes
          {
            trace_id: span.trace_id,
            span_id: span.id,
            parent_span_id: span.parent_id,
            name: span.name,
            kind: convert_span_kind,
            start_time_unix_nano: convert_to_unix_nano(span[:ts]),
            end_time_unix_nano: convert_to_unix_nano(span[:ts] + (span[:d] || 0)),
            status: convert_status,
            attributes: [] # Will be populated by specific converters
          }
        end

        # Convert Instana span kind to OTLP span kind
        # Instana uses :k for span kind: 1=entry/server, 2=exit/client, 3=intermediate/internal
        # OTLP uses: 0=unspecified, 1=internal, 2=server, 3=client, 4=producer, 5=consumer
        # @return [Integer] OTLP span kind enum value
        def convert_span_kind
          case span[:k]
          when 1 then 2  # Instana entry/server → OTLP SERVER
          when 2 then 3  # Instana exit/client → OTLP CLIENT
          when 3 then 1  # Instana intermediate/internal → OTLP INTERNAL
          else 0         # SPAN_KIND_UNSPECIFIED
          end
        end

        # Convert timestamp to Unix nanoseconds
        # @param time [Time, Integer] The timestamp
        # @return [Integer] Unix timestamp in nanoseconds
        def convert_to_unix_nano(time)
          return time if time.is_a?(Integer)

          (time.to_f * 1_000_000_000).to_i
        end

        # Convert span status to OTLP status
        # @return [Hash] OTLP status object
        def convert_status
          {
            code: span[:error] ? 2 : 1, # ERROR : OK
            message: span[:error] ? extract_error_message : ''
          }
        end

        # Extract error message from span
        # @return [String] Error message
        def extract_error_message
          # TODO: Implement error message extraction
        end

        # Convert span attributes to OTLP attributes
        # Subclasses should override this method to provide type-specific attribute conversion
        # @return [Array<Hash>] Array of OTLP key-value pairs
        def convert_attributes
          []
        end

        # Convert attribute value to OTLP value format
        # @param value [Object] The attribute value
        # @return [Hash] OTLP value object
        def convert_attribute_value(value)
          case value
          when String
            { string_value: value }
          when Integer
            { int_value: value }
          when Float
            { double_value: value }
          when TrueClass, FalseClass
            { bool_value: value }
          when Array
            { array_value: { values: value.map { |v| convert_attribute_value(v) } } }
          else
            { string_value: value.to_s }
          end
        end

        # Check if span has errors
        # @return [Boolean] true if span has errors
        def errors?
          span[:error] == true
        end
      end
    end
  end
end
