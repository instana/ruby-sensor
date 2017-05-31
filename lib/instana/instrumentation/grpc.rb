if defined?(GRPC::ActiveCall)
  GRPC::ClientStub.class_eval do
    def request_response_with_instana(method, *others, **options)
      unless ::Instana.tracer.tracing?
        return request_response_without_instana(method, *others, **options)
      end

      ::Instana.tracer.log_entry(:'net-http')
      kv_payload = { http: {} }
      kv_payload[:http][:method] = 'GRPC'
      kv_payload[:http][:host] = @host
      kv_payload[:http][:url] = method

      context = ::Instana.tracer.context
      if context
        options[:metadata] = (options[:metadata] || {}).merge(
          'x-instana-t' => context.trace_id_header,
          'x-instana-s' => context.span_id_header
        )
      end

      request_response_without_instana(method, *others, **options)
    rescue => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_exit(:'net-http', kv_payload)
    end

    ::Instana.logger.warn 'Instrumenting GRPC client'

    alias request_response_without_instana request_response
    alias request_response request_response_with_instana
  end
end

if defined?(GRPC::RpcDesc)
  GRPC::RpcDesc.class_eval do
    def run_server_method_with_instana(active_call, mth)
      unless ::Instana.tracer.tracing?
        run_server_method_without_instana(active_call, mth)
      end

      metadata = active_call.metadata

      kvs = { http: {} }
      kvs[:http][:method] = 'GRPC'
      kvs[:http][:url] = "/#{mth.owner.service_name}/#{name}"
      kvs[:http][:host] = Socket.gethostname

      incoming_context = {}
      if metadata.key?('x-instana-t')
        incoming_context[:trace_id]  = ::Instana::Util.header_to_id(metadata['x-instana-t'])
        incoming_context[:span_id]   = ::Instana::Util.header_to_id(metadata['x-instana-s']) if metadata.key?('x-instana-s')
        incoming_context[:level]     = metadata['x-instana-l'] if metadata.key?('x-instana-l')
      end

      ::Instana.tracer.log_start_or_continue(:rack, {}, incoming_context)
      run_server_method_without_instana(active_call, mth)
    rescue => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_end(:rack, kvs)
    end

    ::Instana.logger.warn 'Instrumenting GRPC server'

    alias run_server_method_without_instana run_server_method
    alias run_server_method run_server_method_with_instana
  end
end
