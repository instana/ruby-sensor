call_types = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

module Instana
  module Instrumentation
    module GRPCCientInstrumentation
      CALL_TYPES = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

      CALL_TYPES.each do |call_type|
        define_method(call_type) do |method, *others, **options|
          begin
            kvs = { rpc: {} }

            unless ::Instana.tracer.tracing?
              return super(method, *others, **options)
            end

            kvs[:rpc][:flavor] = :grpc
            kvs[:rpc][:host] = @host
            kvs[:rpc][:call] = method
            kvs[:rpc][:call_type] = call_type

            ::Instana.tracer.log_entry(:'rpc-client', kvs)

            context = ::Instana.tracer.context
            if context
              options[:metadata] = (options[:metadata] || {}).merge(
                'x-instana-t' => context.trace_id_header,
                'x-instana-s' => context.span_id_header
              )
            end

            super(method, *others, **options)
          rescue => e
            kvs[:rpc][:error] = true
            ::Instana.tracer.log_info(kvs)
            ::Instana.tracer.log_error(e)
            raise
          ensure
            ::Instana.tracer.log_exit(:'rpc-client', {})
          end
        end
      end
    end
  end
end

module Instana
  module Instrumentation
    module GRPCServerInstrumentation
      CALL_TYPES = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

      CALL_TYPES.each do |call_type|
        define_method(:"handle_#{call_type}") do |active_call, mth, *others|
          begin
            kvs = { rpc: {} }
            metadata = active_call.metadata

            incoming_context = {}
            if metadata.key?('x-instana-t')
              incoming_context[:trace_id]  = ::Instana::Util.header_to_id(metadata['x-instana-t'])
              incoming_context[:span_id]   = ::Instana::Util.header_to_id(metadata['x-instana-s']) if metadata.key?('x-instana-s')
              incoming_context[:level]     = metadata['x-instana-l'] if metadata.key?('x-instana-l')
            end

            kvs[:rpc][:flavor] = :grpc
            kvs[:rpc][:host] = Socket.gethostname
            kvs[:rpc][:call] = "/#{mth.owner.service_name}/#{name}"
            kvs[:rpc][:call_type] = call_type
            kvs[:rpc][:peer] = { address: active_call.peer }

            ::Instana.tracer.log_start_or_continue(
              :'rpc-server', kvs, incoming_context
            )

            super(active_call, mth, *others)
          rescue => e
            kvs[:rpc][:error] = true
            ::Instana.tracer.log_info(kvs)
            ::Instana.tracer.log_error(e)
            raise
          ensure
            ::Instana.tracer.log_end(:'rpc-server', {}) if ::Instana.tracer.tracing?
          end
        end
      end
    end
  end
end
