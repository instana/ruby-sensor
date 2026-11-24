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
          rpc_data = span[:data]&.[](:rpc)
          return super unless rpc_data

          system_name = rpc_data[:flavor] == :actioncable ? 'actioncable' : 'grpc'
          method_name = if rpc_data[:flavor] == :actioncable
                          rpc_data[:call].to_s.strip
                        else
                          rpc_data[:call].to_s.delete_prefix('/').strip
                        end

          if method_name.empty? || method_name == '_OTHER'
            system_name
          else
            method_name
          end
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

        # Convert gRPC span attributes
        def convert_grpc_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, Instana::Exporter::Otlp::RPC_SYSTEM_ATTR, 'grpc')

          # RPC method and method_original
          convert_grpc_method(attributes, rpc_data)

          # Server host and port
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, rpc_data[:host])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, parse_port(rpc_data[:port]))

          # Network peer address (peer.address → network.peer.address)
          peer = rpc_data[:peer]
          if peer
            add_attribute(attributes, OpenTelemetry::SemConv::NETWORK::NETWORK_PEER_ADDRESS, peer[:address])
            add_attribute(attributes, OpenTelemetry::SemConv::NETWORK::NETWORK_PEER_PORT, parse_port(peer[:port]))
          end

          # gRPC response status code (string, e.g. "OK", "DEADLINE_EXCEEDED")
          status_code = grpc_response_status_code(rpc_data)
          add_attribute(attributes, 'rpc.response.status_code', status_code)

          # gRPC-specific attributes
          add_attribute(attributes, 'rpc.grpc.call_type', rpc_data[:call_type])
        end

        def convert_grpc_method(attributes, rpc_data)
          return unless rpc_data[:call]

          raw_call = rpc_data[:call].to_s
          cleaned = raw_call.delete_prefix('/')

          if cleaned == '_OTHER' || raw_call == '_OTHER'
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_METHOD, '_OTHER')
            add_attribute(attributes, 'rpc.method_original', rpc_data[:method_original] || raw_call)
          else
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::RPC::RPC_METHOD, cleaned)
          end
        end

        # Convert ActionCable span attributes
        def convert_action_cable_attributes(attributes, rpc_data)
          # RPC system
          add_attribute(attributes, Instana::Exporter::Otlp::RPC_SYSTEM_ATTR, 'actioncable')

          # ActionCable-specific attributes
          add_attribute(attributes, 'rails.actioncable.channel', rpc_data[:call])
          add_attribute(attributes, 'rails.actioncable.call_type', rpc_data[:call_type])

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

        # Parse port value to integer, returns nil if invalid or out of range
        def parse_port(port)
          return nil unless port

          int_port = port.to_i
          int_port if int_port >= 0 && int_port <= 65_535
        end

        # Known gRPC status code names
        GRPC_STATUS_CODE_NAMES = %w[
          OK
          CANCELLED
          UNKNOWN
          INVALID_ARGUMENT
          DEADLINE_EXCEEDED
          NOT_FOUND
          ALREADY_EXISTS
          PERMISSION_DENIED
          RESOURCE_EXHAUSTED
          FAILED_PRECONDITION
          ABORTED
          OUT_OF_RANGE
          UNIMPLEMENTED
          INTERNAL
          UNAVAILABLE
          DATA_LOSS
          UNAUTHENTICATED
        ].freeze

        def grpc_response_status_code(rpc_data)
          error_count = span[:ec].to_i
          return 'OK' if error_count.zero?

          # Attempt to extract gRPC status string from error message
          error_msg = rpc_data[:error].to_s
          GRPC_STATUS_CODE_NAMES.each do |name|
            return name if error_msg.include?(name)
          end

          'UNKNOWN'
        end
      end
    end
  end
end
