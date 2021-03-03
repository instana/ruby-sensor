# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'rack'
require 'instana/instrumentation/instrumented_request'

module Instana
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      req = InstrumentedRequest.new(env)
      return skip_call(env, req) if req.skip_trace?
      kvs = {
        http: req.request_tags,
        service: ENV['INSTANA_SERVICE_NAME']
      }.compact

      current_span = ::Instana.tracer.log_start_or_continue(:rack, {}, req.incoming_context)

      status, headers, response = @app.call(env)

      if ::Instana.tracer.tracing?
        unless req.correlation_data.empty?
          current_span[:crid] = req.correlation_data[:id]
          current_span[:crtp] = req.correlation_data[:type]
        end

        if !req.instana_ancestor.empty? && req.continuing_from_trace_parent?
          current_span[:ia] = req.instana_ancestor
        end

        if req.continuing_from_trace_parent?
          current_span[:tp] = true
        end

        if req.external_trace_id?
          current_span[:lt] = req.external_trace_id
        end

        if req.synthetic?
          current_span[:sy] = true
        end

        # In case some previous middleware returned a string status, make sure that we're dealing with
        # an integer.  In Ruby nil.to_i, "asdfasdf".to_i will always return 0 from Ruby versions 1.8.7 and newer.
        # So if an 0 status is reported here, it indicates some other issue (e.g. no status from previous middleware)
        # See Rack Spec: https://www.rubydoc.info/github/rack/rack/file/SPEC#label-The+Status
        kvs[:http][:status] = status.to_i

        if status.to_i.between?(500, 511)
          # Because of the 5xx response, we flag this span as errored but
          # without a backtrace (no exception)
          ::Instana.tracer.log_error(nil)
        end

        # If the framework instrumentation provides a path template,
        # pass it into the span here.
        # See: https://www.instana.com/docs/tracing/custom-best-practices/#path-templates-visual-grouping-of-http-endpoints
        kvs[:http][:path_tpl] = env['INSTANA_HTTP_PATH_TEMPLATE'] if env['INSTANA_HTTP_PATH_TEMPLATE']

        # Save the span context before the trace ends so we can place
        # them in the response headers in the ensure block
        trace_context = ::Instana.tracer.current_span.context
      end

      [status, headers, response]
    rescue Exception => e
      ::Instana.tracer.log_error(e) if ::Instana.tracer.tracing?
      raise
    ensure
      if ::Instana.tracer.tracing?
        if headers
          # Set response headers; encode as hex string
          headers['X-Instana-T'] = trace_context.trace_id_header
          headers['X-Instana-S'] = trace_context.span_id_header
          headers['X-Instana-L'] = '1'

          headers['Traceparent'] = trace_context.trace_parent_header
          headers['Tracestate'] = trace_context.trace_state_header

          headers['Server-Timing'] = "intid;desc=#{trace_context.trace_id_header}"
        end

        ::Instana.tracer.log_end(:rack, kvs)
      end
    end

    private

    def skip_call(env, req)
      ::Instana.logger.debug('Skipping tracing since X-Instana-L is set to 0.')
      id = ::Instana::Util.generate_id
      trace_context = ::Instana::SpanContext.new(id, id, 0, req.incoming_context)
      status, headers, response = @app.call(env)

      headers['X-Instana-L'] = '0'

      headers['Traceparent'] = trace_context.trace_parent_header
      headers['Tracestate'] = trace_context.trace_state_header

      [status, headers, response]
    end
  end
end
