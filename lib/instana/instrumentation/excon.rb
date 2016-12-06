module Instana
  module Instrumentation
    module ExconConnection
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :request)
        ::Instana::Util.method_alias(klass, :requests)
      end

      def request_with_instana(params={}, &block)
        dnt = true if !::Instana.tracer.tracing? || params[:pipeline] ||
            ::Instana.tracer.current_trace.current_span_name?(:excon)

        if dnt
          return request_without_instana(params, &block)
        end

        pre_payload = { :http => {} }
        pre_payload[:http][:url] = "#{@socket_key}#{@data[:path]}"
        pre_payload[:http][:method] = params[:method] if params.key?(:method)

        ::Instana.tracer.log_entry(:excon, pre_payload)

        # Set request headers; encode IDs as hexadecimal strings
        our_trace_id = ::Instana.tracer.trace_id
        our_span_id  = ::Instana.tracer.span_id
        @data[:headers]['X-Instana-T'] = ::Instana.tracer.id_to_header(our_trace_id)
        @data[:headers]['X-Instana-S'] = ::Instana.tracer.id_to_header(our_span_id)

        response = request_without_instana(params, &block)

        # Pickup response headers; convert back to base 10 integer
        if response.headers["X-Instana-T"]
          their_trace_id = ::Instana.tracer.header_to_id(response.headers['X-Instana-T'])

          if our_trace_id != their_trace_id
            ::Instana.logger.debug "#{Thread.current}: Trace ID mismatch on excon response! ours: #{our_trace_id} theirs: #{their_trace_id}"
          end
        end

        ::Instana.tracer.log_info({ :http => {:status => response.status } })
        response
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:excon) unless dnt
      end

      def requests_with_instana(pipeline_params)
        ::Instana.tracer.log_entry(:excon_pipeline)

        requests_without_instana(pipeline_params)
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:excon_pipeline)
      end
    end
  end
end

if defined?(::Excon) && ::Instana.config[:excon][:enabled]
  ::Instana.logger.warn "Instrumenting excon"
  ::Excon::Connection.send(:include, ::Instana::Instrumentation::ExconConnection)
end
