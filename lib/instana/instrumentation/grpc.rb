# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

call_types = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

module Instana
  module Instrumentation
    module GRPCCientInstrumentation
      CALL_TYPES = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

      CALL_TYPES.each do |call_type| # rubocop:disable Metrics/BlockLength
        define_method(call_type) do |method, *others, **options| # rubocop:disable Metrics/BlockLength
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
              extra = {
                'x-instana-t' => context.trace_id_header,
                'x-instana-s' => context.span_id_header,
                'x-instana-l' => context.level.to_s,
                'traceparent' => context.trace_parent_header,
                'tracestate' => context.trace_state_header
              }
              extra.reject! { |_, v| v.nil? || v.empty? }
              options[:metadata] = (options[:metadata] || {}).merge(extra)
            end

            super(method, *others, **options)
          rescue => e
            kvs[:rpc][:error] = true
            current_span.add_attributes(kvs)
            current_span.record_exception(e)
            raise
          ensure
            current_span&.finish
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

            incoming_context = extract_grpc_context(metadata)

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
            current_span.add_attributes(kvs)
            current_span.record_exception(e)
            raise
          ensure
            current_span&.finish
          end
        end
      end

      private

      def extract_grpc_context(metadata)
        if metadata.key?('x-instana-t')
          extract_instana_grpc_context(metadata)
        elsif metadata.key?('traceparent')
          extract_w3c_grpc_context(metadata)
        end
      end

      def extract_instana_grpc_context(metadata)
        SpanContext.new(
          trace_id: ::Instana::Util.header_to_id(metadata['x-instana-t']),
          span_id: metadata.key?('x-instana-s') ? ::Instana::Util.header_to_id(metadata['x-instana-s']) : nil,
          level: metadata['x-instana-l'] || 1
        )
      end

      def extract_w3c_grpc_context(metadata)
        ctx = ::Instana::Util.parse_w3c_trace_context(metadata['traceparent'], metadata['tracestate'])
        return nil unless ctx

        SpanContext.new(trace_id: ctx[:trace_id],
                        span_id: ctx[:span_id],
                        level: ctx[:level],
                        baggage: ctx.slice(:external_trace_id, :external_trace_flags, :external_state))
      end
    end
  end
end
