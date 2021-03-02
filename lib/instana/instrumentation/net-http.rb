# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'net/http'

module Instana
  module Instrumentation
    module NetHTTPInstrumentation
      def request(*args, &block)
        if !Instana.tracer.tracing? || Instana.tracer.current_span.exit_span? || !started?
          do_skip = true
          return super(*args, &block)
        end

        ::Instana.tracer.log_entry(:'net-http')

        # Send out the tracing context with the request
        request = args[0]

        # Set request headers; encode IDs as hexadecimal strings
        t_context = ::Instana.tracer.context
        request['X-Instana-T'] = t_context.trace_id_header
        request['X-Instana-S'] = t_context.span_id_header

        if ::Instana.config[:w3_trace_correlation]
          request['Traceparent'] = t_context.trace_parent_header
          request['Tracestate'] = t_context.trace_state_header
        end

        # Collect up KV info now in case any exception is raised
        kv_payload = { :http => {} }
        kv_payload[:http][:method] = request.method

        if request.uri
          uri_without_query = request.uri.dup.tap { |r| r.query = nil }
          kv_payload[:http][:url] = uri_without_query.to_s
          kv_payload[:http][:params] = ::Instana.secrets.remove_from_query(request.uri.query)
        else
          if use_ssl?
            kv_payload[:http][:url] = "https://#{@address}:#{@port}#{request.path}"
          else
            kv_payload[:http][:url] = "http://#{@address}:#{@port}#{request.path}"
          end
        end

        kv_payload[:http][:url] = ::Instana.secrets.remove_from_query(kv_payload[:http][:url])

        # The core call
        response = super(*args, &block)

        kv_payload[:http][:status] = response.code
        if response.code.to_i.between?(500, 511)
          # Because of the 5xx response, we flag this span as errored but
          # without a backtrace (no exception)
          ::Instana.tracer.log_error(nil)
        end

        response
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:'net-http', kv_payload) unless do_skip
      end
    end
  end
end
