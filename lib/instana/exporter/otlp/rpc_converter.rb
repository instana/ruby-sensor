# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/rpc'
require 'opentelemetry/semconv/incubating/code'
require 'opentelemetry/semconv/server'
require 'opentelemetry/semconv/network'

module Instana
  module Exporter
    module Otlp
      # Converter for RPC spans (gRPC, ActionCable) to OTLP format
      class RpcConverter < BaseConverter
        # Build OTel-compliant span name for RPC spans
        #
        # Formulas per SPAN_NAME_PATTERNS.txt Section 4:
        #   gRPC        → "{package.Service/Method}"  (leading "/" stripped per OTel spec)
        #   ActionCable → "{ChannelClass#action}"      (call string used as-is)
        #
        # @return [String] The span name
        def span_name
          rpc_data = span[:data]&.[](:rpc) || {}

          if rpc_data[:flavor] == :actioncable
            rpc_data[:call].to_s
          else
            # Strip the mandatory leading slash per gRPC/OTel spec
            rpc_data[:call].to_s.delete_prefix('/')
          end.then { |n| n.empty? ? super : n }
        end

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

        # gRPC status code mapping: 0 = OK for success, otherwise derive from error
        GRPC_STATUS_CODE_OK = 0

        # Convert gRPC span attributes
        def convert_grpc_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SYSTEM_NAME, 'grpc')

          # RPC service and method
          if rpc_data[:call]
            service, method = parse_grpc_call(rpc_data[:call])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SERVICE, service)
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_METHOD, method)
          end

          # Server host and port
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rpc_data[:host])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, parse_port(rpc_data[:port]))

          # Network peer address (peer.address → network.peer.address)
          peer = rpc_data[:peer]
          if peer
            add_attribute(attributes, OpenTelemetry::SemConv::NETWORK::NETWORK_PEER_ADDRESS, peer[:address])
            add_attribute(attributes, OpenTelemetry::SemConv::NETWORK::NETWORK_PEER_PORT, parse_port(peer[:port]))
          end

          # gRPC status code (integer): 0 = OK for success spans
          grpc_status = grpc_status_code(rpc_data)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_GRPC_STATUS_CODE, grpc_status)

          # gRPC-specific attributes
          add_attribute(attributes, 'rpc.grpc.call_type', rpc_data[:call_type])
        end

        # Convert ActionCable span attributes
        def convert_action_cable_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_SYSTEM_NAME, 'actioncable')

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

        # Parse port value to integer, returns nil if invalid or out of range
        def parse_port(port)
          return nil unless port

          int_port = port.to_i
          int_port if int_port >= 0 && int_port <= 65_535
        end

        # Map to gRPC status code integer.
        # For successful spans (ec = 0) → 0 (OK).
        # For error spans with a recognized gRPC status string in the error → map it.
        # Otherwise → nil (omit the attribute).
        GRPC_STATUS_CODES = {
          'OK' => 0,
          'CANCELLED' => 1,
          'UNKNOWN' => 2,
          'INVALID_ARGUMENT' => 3,
          'DEADLINE_EXCEEDED' => 4,
          'NOT_FOUND' => 5,
          'ALREADY_EXISTS' => 6,
          'PERMISSION_DENIED' => 7,
          'RESOURCE_EXHAUSTED' => 8,
          'FAILED_PRECONDITION' => 9,
          'ABORTED' => 10,
          'OUT_OF_RANGE' => 11,
          'UNIMPLEMENTED' => 12,
          'INTERNAL' => 13,
          'UNAVAILABLE' => 14,
          'DATA_LOSS' => 15,
          'UNAUTHENTICATED' => 16
        }.freeze

        def grpc_status_code(rpc_data)
          error_count = span[:ec].to_i
          return GRPC_STATUS_CODE_OK if error_count.zero?

          # Attempt to extract gRPC status string from error message
          error_msg = rpc_data[:error].to_s
          GRPC_STATUS_CODES.each do |name, code|
            return code if error_msg.include?(name)
          end

          GRPC_STATUS_CODES['UNKNOWN']
        end
      end
    end
  end
end
