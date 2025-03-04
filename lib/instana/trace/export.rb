# (c) Copyright IBM Corp. 2025
# (c) Copyright Instana Inc. 2025

module Instana
  module Trace
    # The Export module contains the built-in exporters and span processors for the OpenTelemetry
    # reference implementation.
    module Export
      # Raised when an export fails; spans are available via :spans accessor
      class ExportError < OpenTelemetry::Error
        # Returns the {Span} array for this exception
        #
        # @return [Array<OpenTelemetry::SDK::Trace::Span>]
        attr_reader :spans

        # @param [Array<OpenTelemetry::SDK::Trace::Span>] spans the array of spans that failed to export
        def initialize(spans)
          super("Unable to export #{spans.size} spans")
          @spans = spans
        end
      end

      # Result codes for the SpanExporter#export method and the SpanProcessor#force_flush and SpanProcessor#shutdown methods.

      # The operation finished successfully.
      SUCCESS = 0

      # The operation finished with an error.
      FAILURE = 1

      # Additional result code for the SpanProcessor#force_flush and SpanProcessor#shutdown methods.

      # The operation timed out.
      TIMEOUT = 2
    end
  end
end
