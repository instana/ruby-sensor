# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'resource'
require 'opentelemetry/trace'

module Instana
  module Exporter
    module Otlp
      # Base class for all OTLP span converters
      #
      # Provides common interface and shared functionality for converting Instana spans
      # to OpenTelemetry Protocol (OTLP) compatible span data objects.
      #
      # @abstract Subclasses should override {#convert_attributes} to provide
      #   type-specific attribute conversion logic.
      #
      # @example Creating a custom converter
      #   class MyConverter < BaseConverter
      #     def convert_attributes
      #       attributes = {}
      #       add_attribute(attributes, 'custom.field', span[:data][:custom][:field])
      #       attributes
      #     end
      #   end
      class BaseConverter
        # Represents the instrumentation scope (library) that created the span
        InstrumentationScope = Struct.new(:name, :version)

        # Represents the status of a span (OK, ERROR, or UNSET)
        Status = Struct.new(:code, :description)

        # Adapter to make resource objects compatible with OTLP exporter expectations
        ResourceAdapter = Struct.new(:attributes) do
          # @return [Enumerator] Iterator over resource attributes
          def attribute_enumerator
            attributes.each
          end
        end

        # Plain object that directly implements the interface expected by
        # OpenTelemetry::Exporter::OTLP::Exporter#export
        #
        # This is a simple data structure with the required methods, avoiding
        # unnecessary delegation overhead.
        SpanData = Struct.new(
          :name,
          :trace_id,
          :span_id,
          :parent_span_id,
          :resource,
          :instrumentation_scope,
          :kind,
          :start_timestamp,
          :end_timestamp,
          :attributes,
          :status,
          keyword_init: true
        ) do
          # @return [OpenTelemetry::Trace::Tracestate] Default empty tracestate
          def tracestate
            OpenTelemetry::Trace::Tracestate::DEFAULT
          end

          # @return [Integer] Number of attributes recorded
          def total_recorded_attributes
            attributes.size
          end

          # @return [Array] Empty array (events not currently supported)
          def events
            EMPTY_ARRAY
          end

          # @return [Integer] Zero (events not currently supported)
          def total_recorded_events
            0
          end

          # @return [Array] Empty array (links not currently supported)
          def links
            EMPTY_ARRAY
          end

          # @return [Integer] Zero (links not currently supported)
          def total_recorded_links
            0
          end

          # @return [Boolean] False (remote parent detection not implemented)
          def parent_span_is_remote
            false
          end

          # @return [OpenTelemetry::Trace::TraceFlags] Default trace flags
          def trace_flags
            OpenTelemetry::Trace::TraceFlags::DEFAULT
          end

          private

          EMPTY_ARRAY = [].freeze
        end

        # Milliseconds to nanoseconds conversion factor
        MS_TO_NS = 1_000_000
        private_constant :MS_TO_NS

        # @param span [Instana::Trace::Span] The span to convert
        # @param resource [Object, nil] Optional resource information (defaults to global resource)
        def initialize(span, resource = nil)
          @span = span
          @resource = resource || Resource.instance
        end

        # Convert the Instana span to OTLP-compatible span data
        #
        # @return [SpanData] Converted span data object ready for export
        def convert
          SpanData.new(
            name: span_name,
            trace_id: format_trace_id(span[:t]),
            span_id: format_span_id(span[:s]),
            parent_span_id: format_parent_span_id,
            resource: resource_adapter,
            instrumentation_scope: instrumentation_scope,
            kind: convert_span_kind,
            start_timestamp: convert_to_unix_nano(span[:ts]),
            end_timestamp: calculate_end_timestamp,
            attributes: convert_attributes,
            status: convert_status
          )
        end

        protected

        attr_reader :span, :resource

        # Format trace ID to the expected 16-byte binary format
        #
        # @param trace_id [String, nil] The trace ID as hex string
        # @return [String] Formatted trace ID as 16-byte binary string
        def format_trace_id(trace_id)
          return OpenTelemetry::Trace::INVALID_TRACE_ID unless trace_id

          # Pad to 32 hex characters (16 bytes) and convert to binary
          hex_string = trace_id.to_s.rjust(32, '0')
          [hex_string].pack('H*')
        end

        # Format span ID to the expected 8-byte binary format
        #
        # @param span_id [String, nil] The span ID as hex string
        # @return [String, nil] Formatted span ID as 8-byte binary string, or nil if input is nil
        def format_span_id(span_id)
          return nil unless span_id

          # Pad to 16 hex characters (8 bytes) and convert to binary
          hex_string = span_id.to_s.rjust(16, '0')
          [hex_string].pack('H*')
        end

        # Convert Instana span kind to OpenTelemetry span kind
        #
        # Instana span kinds:
        #   1 = entry/server
        #   2 = exit/client
        #   3 = intermediate/internal
        #
        # @return [Symbol] One of :server, :client, :internal, :producer, or :consumer
        def convert_span_kind
          # Explicit kind takes precedence
          case span[:k]
          when 1 then return :server
          when 2 then return :client
          when 3 then return :internal
          end

          # Infer from span name if no explicit kind
          infer_span_kind_from_name
        end

        # Convert Instana millisecond timestamps to Unix nanoseconds
        #
        # @param time [Time, Integer, nil] The timestamp (Time object or milliseconds since epoch)
        # @return [Integer] Unix timestamp in nanoseconds
        def convert_to_unix_nano(time)
          case time
          when nil
            0
          when Integer
            time * MS_TO_NS
          else
            (time.to_f * 1_000_000_000).to_i
          end
        end

        # Convert span status to OpenTelemetry status object
        #
        # @return [Status] Status object with code and optional description
        def convert_status
          if span[:error]
            error_message = extract_error_message
            Status.new(OpenTelemetry::Trace::Status::ERROR, error_message.to_s)
          else
            Status.new(OpenTelemetry::Trace::Status::UNSET, '')
          end
        end

        # Extract error message from span
        # @return [String, nil] Error message
        def extract_error_message
          # TODO: Implement error message extraction
        end

        # Convert span attributes to OTLP-compatible attributes
        #
        # Subclasses should override this method to provide type-specific
        # attribute conversion logic.
        #
        # @return [Hash] Hash of attribute key-value pairs
        def convert_attributes
          {}
        end

        # Add an attribute to the attributes hash if value is not nil
        #
        # @param attributes [Hash] The attributes hash to add to
        # @param key [String, Symbol] The attribute key
        # @param value [Object] The attribute value
        # @return [void]
        def add_attribute(attributes, key, value)
          return if value.nil?

          attributes[key] = normalize_attribute_value(value)
        end

        # Normalize attribute value to OTLP-compatible types
        #
        # OTLP supports: String, Integer, Float, Boolean, and Arrays of these types
        #
        # @param value [Object] The value to normalize
        # @return [String, Integer, Float, Boolean, Array] Normalized value
        def normalize_attribute_value(value)
          case value
          when String, Integer, Float, TrueClass, FalseClass
            value
          when Symbol
            value.to_s
          when Array
            value.map { |item| normalize_attribute_value(item) }
          else
            value.to_s
          end
        end

        private

        # Get the span name as a string
        #
        # @return [String] The span name
        def span_name
          span[:n].to_s
        end

        # Format parent span ID, returning INVALID_SPAN_ID if no parent
        #
        # @return [String] Formatted parent span ID or INVALID_SPAN_ID
        def format_parent_span_id
          format_span_id(span[:p]) || OpenTelemetry::Trace::INVALID_SPAN_ID
        end

        # Calculate end timestamp from start time and duration
        #
        # @return [Integer] End timestamp in nanoseconds
        def calculate_end_timestamp
          start_time = span[:ts] || 0
          duration = span[:d] || 0
          convert_to_unix_nano(start_time + duration)
        end

        # Infer span kind from span name using Instana's span kind registry
        #
        # @return [Symbol] Inferred span kind
        def infer_span_kind_from_name
          span_name = span[:n]&.to_sym
          return :server if ::Instana::SpanKind::ENTRY_SPANS.include?(span_name)
          return :client if ::Instana::SpanKind::EXIT_SPANS.include?(span_name)

          :internal
        end

        # Get or create resource adapter for OTLP export
        #
        # @return [Object] Resource adapter with attribute_enumerator method
        def resource_adapter
          return resource if resource.respond_to?(:attribute_enumerator)

          ResourceAdapter.new(resource)
        end

        # Get or create instrumentation scope
        #
        # @return [InstrumentationScope] Scope identifying the Instana Ruby sensor
        def instrumentation_scope
          @instrumentation_scope ||= InstrumentationScope.new('instana-ruby', ::Instana::VERSION)
        end
      end
    end
  end
end
