# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

module Instana
  module Exporter
    module Otlp
      # Converter for RPC spans to OTLP format
      # Handles conversion of RPC-related spans (gRPC, etc.)
      # NOTE: This converter is a placeholder for future implementation
      class RpcConverter < BaseConverter
        # Convert RPC span to OTLP format
        # @return [Hash] Converted RPC span data in OTLP format
      end
    end
  end
end
