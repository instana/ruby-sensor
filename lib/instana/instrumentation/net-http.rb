# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'net/http'

module Instana
  module Instrumentation
    module NetHTTPInstrumentation
      def request(*args, &block)
        if skip_instrumentation?
          do_skip = true
          return super(*args, &block)
        end

        current_span = ::Instana.tracer.start_span(:'net-http')

        # Send out the tracing context with the request
        request = args[0]

        # Set request headers; encode IDs as hexadecimal strings
        t_context = ::Instana.tracer.context
        request['X-Instana-L'] = t_context.level.to_s

        if t_context.active?
          request['X-Instana-T'] = t_context.trace_id_header
          request['X-Instana-S'] = t_context.span_id_header
        end

        request['Traceparent'] = t_context.trace_parent_header
        request['Tracestate'] = t_context.trace_state_header unless t_context.trace_state_header.empty?

        # Collect up KV info now in case any exception is raised
        kv_payload = { :http => {} }
        kv_payload[:http][:method] = request.method

        if request.uri
          uri_without_query = request.uri.dup.tap { |r| r.query = nil }
          kv_payload[:http][:url] = uri_without_query.to_s.gsub(/\?\z/, '')
          kv_payload[:http][:params] = ::Instana.secrets.remove_from_query(request.uri.query)
        else
          if use_ssl?
            kv_payload[:http][:url] = "https://#{@address}:#{@port}#{request.path}"
          else
            kv_payload[:http][:url] = "http://#{@address}:#{@port}#{request.path}"
          end
        end

        kv_payload[:http][:url] = ::Instana.secrets.remove_from_query(kv_payload[:http][:url]).gsub(/\?\z/, '')

        # The core call
        response = super(*args, &block)

        kv_payload[:http][:status] = response.code
        if response.code.to_i >= 500
          # Because of the 5xx response, we flag this span as errored but
          # without a backtrace (no exception)
          current_span.record_exception(nil)
        end
        extra_headers = extra_header_tags(response)&.merge(extra_header_tags(request))
        kv_payload[:http][:header] = extra_headers unless extra_headers&.empty?
        response
      rescue => e
        current_span&.record_exception(e)
        raise
      ensure
        current_span&.set_tags(kv_payload)
        current_span&.finish unless do_skip
      end

      def skip_instrumentation?
        dnt_spans = [:dynamodb, :sqs, :sns, :s3]
        !Instana.tracer.tracing? || !started? || !Instana.config[:nethttp][:enabled] ||
          (!::Instana.tracer.current_span.nil? && dnt_spans.include?(::Instana.tracer.current_span.name))
      end

      def extra_header_tags(request_response)
        return nil unless ::Instana.agent.extra_headers

        headers = {}

        ::Instana.agent.extra_headers.each do |custom_header|
          # Headers are available in this format: HTTP_X_CAPTURE_THIS

          headers[custom_header.to_sym] = request_response[custom_header] if request_response.key?(custom_header)
        end

        headers
      end
    end
  end
end
