if defined?(::Excon) && ::Instana.config[:excon][:enabled]
  module Instana
    module Instrumentation
      class Excon < ::Excon::Middleware::Base
        def request_call(datum)
          return @stack.request_call(datum) unless ::Instana.tracer.tracing?

          payload = { :http => {} }
          path = datum[:path].split('?').first
          payload[:http][:url] = "#{datum[:connection].instance_variable_get(:@socket_key)}#{path}"
          payload[:http][:method] = datum[:method] if datum.key?(:method)

          if datum[:pipeline] == true
            # Pass the context along in the datum so we get back on response
            # and can close out the async span
            datum[:instana_context] = ::Instana.tracer.log_async_entry(:excon, payload)
          else
            ::Instana.tracer.log_entry(:excon, payload)
          end

          # Set request headers; encode IDs as hexadecimal strings
          datum[:headers]['X-Instana-T'] = ::Instana.tracer.trace_id_header
          datum[:headers]['X-Instana-S'] = ::Instana.tracer.span_id_header

          @stack.request_call(datum)
        end

        def error_call(datum)
          return @stack.error_call(datum) unless ::Instana.tracer.tracing?

          if datum[:pipeline] == true
            ::Instana.tracer.log_async_error(datum[:error], datum[:instana_context])
          else
            ::Instana.tracer.log_error(datum[:error])
          end
          @stack.error_call(datum)
        end

        def response_call(datum)
          return @stack.response_call(datum) unless ::Instana.tracer.tracing?

          result =  @stack.response_call(datum)

          status = datum[:status]
          if !status && datum.key?(:response) && datum[:response].is_a?(Hash)
            status = datum[:response][:status]
          end

          if datum[:pipeline] == true
            # Pickup context of this async span from datum[:instana_id]
            ::Instana.tracer.log_async_exit(:excon, { :http => {:status => status } }, datum[:instana_context])
          else
            ::Instana.tracer.log_exit(:excon, { :http => {:status => status } })
          end
          result
        end
      end
    end
  end

  ::Instana.logger.warn "Instrumenting excon"
  ::Excon.defaults[:middlewares].unshift(::Instana::Instrumentation::Excon)
end

