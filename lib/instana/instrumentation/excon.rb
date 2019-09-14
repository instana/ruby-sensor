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
            datum[:instana_span] = ::Instana.tracer.log_async_entry(:excon, payload)
            t_context = datum[:instana_span].context
          else
            ::Instana.tracer.log_entry(:excon, payload)
            t_context = ::Instana.tracer.context
          end

          # Set request headers; encode IDs as hexadecimal strings
          datum[:headers]['X-Instana-T'] = t_context.trace_id_header
          datum[:headers]['X-Instana-S'] = t_context.span_id_header

          @stack.request_call(datum)
        end

        def error_call(datum)
          return @stack.error_call(datum) unless ::Instana.tracer.tracing?

          if datum[:pipeline] == true
            ::Instana.tracer.log_async_error(datum[:error], datum[:instana_span])
          else
            ::Instana.tracer.log_error(datum[:error])
          end
          @stack.error_call(datum)
        end

        def response_call(datum)
          # FIXME: Will connect exceptions call a response?
          #
          return @stack.response_call(datum) unless ::Instana.tracer.tracing?

          result =  @stack.response_call(datum)

          status = datum[:status]
          if !status && datum.key?(:response) && datum[:response].is_a?(Hash)
            status = datum[:response][:status]
          end

          if status.between?(500, 511)
            # Because of the 5xx response, we flag this span as errored but
            # without a backtrace (no exception)
            ::Instana.tracer.log_error(nil)
          end

          if datum[:pipeline] == true
            # Pickup context of this async span from datum[:instana_span]
            ::Instana.tracer.log_async_exit(:excon, { :http => {:status => status } }, datum[:instana_span])
          else
            ::Instana.tracer.log_exit(:excon, { :http => {:status => status } })
          end
          result
        end
      end
    end
  end

  ::Instana.logger.debug "Instrumenting Excon"
  ::Excon.defaults[:middlewares].unshift(::Instana::Instrumentation::Excon)
end

