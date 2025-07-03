# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

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

            current_span = ::Instana.tracer.start_span(:'rpc-client', attributes: kvs)

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
            current_span.set_tags(kvs)
            current_span.record_exception(e)
            raise
          ensure
            current_span.finish
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
            span = OpenTelemetry::Trace.non_recording_span(incoming_context) if incoming_context
            parent_context = Trace.context_with_span(span) if incoming_context

            current_span = ::Instana.tracer.start_span(:'rpc-server', attributes: kvs, with_parent: parent_context)

            super(active_call, mth, *others)
          rescue => e
            kvs[:rpc][:error] = true
            current_span.set_tags(kvs)
            current_span.record_exception(e)
            raise
          ensure
            current_span.finish if ::Instana.tracer.tracing?
          end
        end
      end
    end
  end
end
