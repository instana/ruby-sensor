call_types = [:request_response, :client_streamer, :server_streamer, :bidi_streamer]

if defined?(GRPC::ActiveCall) && ::Instana.config[:grpc][:enabled]
  call_types.each do |call_type|
    GRPC::ClientStub.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{call_type}_with_instana(method, *others, **options)
        kvs = { rpc: {} }

        unless ::Instana.tracer.tracing?
          return #{call_type}_without_instana(method, *others, **options)
        end

        kvs[:rpc][:flavor] = :grpc
        kvs[:rpc][:host] = @host
        kvs[:rpc][:call] = method
        kvs[:rpc][:call_type] = :#{call_type}

        ::Instana.tracer.log_entry(:'rpc-client', kvs)

        context = ::Instana.tracer.context
        if context
          options[:metadata] = (options[:metadata] || {}).merge(
            'x-instana-t' => context.trace_id_header,
            'x-instana-s' => context.span_id_header
          )
        end

        #{call_type}_without_instana(method, *others, **options)
      rescue => e
        kvs[:rpc][:error] = true
        ::Instana.tracer.log_info(kvs)
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:'rpc-client', {})
      end

      alias #{call_type}_without_instana #{call_type}
      alias #{call_type} #{call_type}_with_instana
    RUBY
  end
  ::Instana.logger.info 'Instrumenting GRPC client'
end

if defined?(GRPC::RpcDesc) && ::Instana.config[:grpc][:enabled]
  call_types.each do |call_type|
    GRPC::RpcDesc.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def handle_#{call_type}_with_instana(active_call, mth, *others)
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
        kvs[:rpc][:call] = "/\#{mth.owner.service_name}/\#{name}"
        kvs[:rpc][:call_type] = :#{call_type}
        kvs[:rpc][:peer] = { address: active_call.peer }

        ::Instana.tracer.log_start_or_continue(
          :'rpc-server', kvs, incoming_context
        )

        handle_#{call_type}_without_instana(active_call, mth, *others)
      rescue => e
        kvs[:rpc][:error] = true
        ::Instana.tracer.log_info(kvs)
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_end(:'rpc-server', {}) if ::Instana.tracer.tracing?
      end

      alias handle_#{call_type}_without_instana handle_#{call_type}
      alias handle_#{call_type} handle_#{call_type}_with_instana
    RUBY
  end
  ::Instana.logger.info 'Instrumenting GRPC server'
end
