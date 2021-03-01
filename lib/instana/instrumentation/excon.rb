# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

module Instana
  module Instrumentation
    class Excon < ::Excon::Middleware::Base
      def request_call(datum)
        return @stack.request_call(datum) unless ::Instana.tracer.tracing? || !Instana.tracer.current_span.exit_span?

        payload = { :http => {} }
        path, query = datum[:path].split('?', 2)
        payload[:http][:url] = ::Instana.secrets.remove_from_query("#{datum[:connection].instance_variable_get(:@socket_key)}#{path}")
        payload[:http][:method] = datum[:method] if datum.key?(:method)
        payload[:http][:params] = ::Instana.secrets.remove_from_query(query || '')

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

        if ::Instana.config[:w3_trace_correlation]
          datum[:headers]['Traceparent'] = t_context.trace_parent_header
          datum[:headers]['Tracestate'] = t_context.trace_state_header
        end

        @stack.request_call(datum)
      end

      def error_call(datum)
        return @stack.error_call(datum) unless ::Instana.tracer.tracing? || !Instana.tracer.current_span.exit_span?

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
        return @stack.response_call(datum) unless ::Instana.tracer.tracing? || !Instana.tracer.current_span.exit_span?

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
