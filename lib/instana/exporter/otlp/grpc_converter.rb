# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semantic_conventions'

module Instana
  module Exporter
    module Otlp
      # Converter for gRPC spans to OTLP format
      class GrpcConverter < BaseConverter
        def convert_attributes
          attributes = {}

          rpc_data = span[:data]&.[](:rpc)
          return attributes unless rpc_data

          # RPC system
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::RPC_SYSTEM, 'grpc')

          # RPC service and method
          if rpc_data[:call]
            service, method = parse_grpc_call(rpc_data[:call])
            add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::RPC_SERVICE, service)
            add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::RPC_METHOD, method)
          end

          # Network peer
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::NET_PEER_NAME, rpc_data[:host])
          add_attribute(attributes, OpenTelemetry::SemanticConventions::Trace::NET_PEER_NAME, rpc_data.dig(:peer, :address))

          # gRPC-specific attributes
          add_attribute(attributes, 'rpc.grpc.call_type', rpc_data[:call_type])

          attributes
        end

        private

        def parse_grpc_call(call)
          parts = call.to_s.split('/')
          return [nil, nil] if parts.size < 3

          [parts[1], parts[2]]
        end
      end
    end
  end
end
