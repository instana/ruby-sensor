# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/rpc'
require 'opentelemetry/semconv/incubating/code'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      # Converter for RPC spans (gRPC, ActionCable) to OTLP format
      class RpcConverter < BaseConverter
        def convert_attributes
          attributes = {}

          rpc_data = span[:data]&.[](:rpc)
          return attributes unless rpc_data

          # Check if this is an ActionCable span
          if rpc_data[:flavor] == :actioncable
            convert_action_cable_attributes(attributes, rpc_data)
          else
            convert_grpc_attributes(attributes, rpc_data)
          end

          attributes
        end

        private

        # Convert gRPC span attributes
        def convert_grpc_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SYSTEM, 'grpc')

          # RPC service and method
          if rpc_data[:call]
            service, method = parse_grpc_call(rpc_data[:call])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SERVICE, service)
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_METHOD, method)
          end

          # Network peer
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rpc_data[:host])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rpc_data.dig(:peer, :address))

          # gRPC-specific attributes
          add_attribute(attributes, 'rpc.grpc.call_type', rpc_data[:call_type])
        end

        # Convert ActionCable span attributes
        def convert_action_cable_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SYSTEM, 'actioncable')

          # ActionCable-specific attributes
          add_attribute(attributes, 'rails.actioncable.channel', rpc_data[:call])
          add_attribute(attributes, 'rails.actioncable.call_type', rpc_data[:call_type])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SERVICE, span[:data]&.[](:service) || span[:service])

          # Extract channel class and action from the call attribute
          # Format can be either "ChannelClass" (for transmit) or "ChannelClass#action" (for action dispatch)
          if rpc_data[:call]
            call_parts = rpc_data[:call].to_s.split('#')
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE, call_parts[0])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_FUNCTION, call_parts[1]) if call_parts[1]
          end

          # Network peer
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rpc_data[:host])
        end

        def parse_grpc_call(call)
          parts = call.to_s.split('/')
          return [nil, nil] if parts.size < 3

          [parts[1], parts[2]]
        end
      end
    end
  end
end
