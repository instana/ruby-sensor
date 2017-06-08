if defined?(GRPC::ActiveCall)
  GRPC::ClientStub.class_eval do
    def request_response_with_instana(method, *others, **options)
      unless ::Instana.tracer.tracing?
        return request_response_without_instana(method, *others, **options)
      end

      kvs = {
        rpc: {
          flavor: :grpc,
          host: @host,
          call: method
        }
      }
      ::Instana.tracer.log_entry(:'rpc-client', {})

      context = ::Instana.tracer.context
      if context
        options[:metadata] = (options[:metadata] || {}).merge(
          'x-instana-t' => context.trace_id_header,
          'x-instana-s' => context.span_id_header
        )
      end

      request_response_without_instana(method, *others, **options)
    rescue => e
      kvs[:rpc][:error] = true
      ::Instana.tracer.log_info(kvs)
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_exit(:'rpc-client', kvs)
    end

    ::Instana.logger.warn 'Instrumenting GRPC client'

    alias request_response_without_instana request_response
    alias request_response request_response_with_instana
  end
end

if defined?(GRPC::RpcDesc)
  [:handle_request_response, :handle_client_streamer].each do |method|
    GRPC::RpcDesc.class_eval(
      <<-RUBY, __FILE__, __LINE__ + 1
        def #{method}_with_instana(active_call, mth)
          metadata = active_call.metadata

          incoming_context = {}
          if metadata.key?('x-instana-t')
            incoming_context[:trace_id]  = ::Instana::Util.header_to_id(metadata['x-instana-t'])
            incoming_context[:span_id]   = ::Instana::Util.header_to_id(metadata['x-instana-s']) if metadata.key?('x-instana-s')
            incoming_context[:level]     = metadata['x-instana-l'] if metadata.key?('x-instana-l')
          end

          kvs = {
            rpc: {
              flavor: :grpc,
              host: Socket.gethostname,
              call: "/\#{mth.owner.service_name}/\#{name}",
              peer: {
                address: active_call.peer
              }
            }
          }
          ::Instana.tracer.log_start_or_continue(
            :'rpc-server', {}, incoming_context
          )

          #{method}_without_instana(active_call, mth)
        rescue => e
          kvs[:rpc][:error] = true
          ::Instana.tracer.log_info(kvs)
          ::Instana.tracer.log_error(e)
          raise
        ensure
          ::Instana.tracer.log_end(:'rpc-server', kvs)
        end

        ::Instana.logger.warn 'Instrumenting GRPC server'

        alias #{method}_without_instana #{method}
        alias #{method} #{method}_with_instana
      RUBY
    )
  end
end
