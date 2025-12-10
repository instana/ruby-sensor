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
      kvs = {
        http: req.request_tags
      }.reject { |_, v| v.nil? }

      parent_context = extract_trace_context(req.incoming_context)

      span = OpenTelemetry::Trace.non_recording_span(parent_context) if parent_context
      parent_context = Trace.context_with_span(span) if parent_context

      current_span = ::Instana.tracer.start_span(:rack, attributes: {}, with_parent: parent_context)
      trace_ctx = OpenTelemetry::Trace.context_with_span(current_span)
      @trace_token = OpenTelemetry::Context.attach(trace_ctx)
      status, headers, response = @app.call(env)

      trace_context = process_span_tags(req, current_span, kvs, status, env) if ::Instana.tracer.tracing?
      merge_response_headers(kvs, headers)
      [status, headers, response]
    rescue Exception => e
      current_span.record_exception(e) if ::Instana.tracer.tracing?
      raise
    ensure
      finalize_trace(current_span, kvs, headers, trace_context) if ::Instana.tracer.tracing?
    end

    private

    def extract_trace_context(incoming_context)
      return nil unless incoming_context

      parent_context = nil

      if incoming_context.is_a?(Hash)
        unless incoming_context.empty?
          parent_context = SpanContext.new(
            trace_id: incoming_context[:trace_id],
            span_id: incoming_context[:span_id],
            level: incoming_context[:level],
            baggage: {
              external_trace_id: incoming_context[:external_trace_id],
              external_state: incoming_context[:external_state],
              external_trace_flags: incoming_context[:external_trace_flags]
            }
          )
        end
      elsif incoming_context.is_a?(SpanContext)
        parent_context = incoming_context
      end
      parent_context
    end

    def process_span_tags(req, current_span, kvs, status, env)
      add_correlation_data(req, current_span)
      add_trace_parent_data(req, current_span)
      add_status_and_error(kvs, status)
      add_path_template(kvs, env)

      # Save the span context before the trace ends so we can place
      # them in the response headers in the ensure block
      ::Instana.tracer.current_span.context
    end

    def add_correlation_data(req, current_span)
      return if req.correlation_data.empty?

      current_span[:crid] = req.correlation_data[:id]
      current_span[:crtp] = req.correlation_data[:type]
    end

    def add_trace_parent_data(req, current_span)
      if !req.instana_ancestor.empty? && req.continuing_from_trace_parent?
        current_span[:ia] = req.instana_ancestor
      end

      current_span[:tp] = true if req.continuing_from_trace_parent?
      current_span[:lt] = req.external_trace_id if req.external_trace_id?
      current_span[:sy] = true if req.synthetic?
    end

    def add_status_and_error(kvs, status)
      # In case some previous middleware returned a string status, make sure that we're dealing with
      # an integer.  In Ruby nil.to_i, "asdfasdf".to_i will always return 0 from Ruby versions 1.8.7 and newer.
      # So if an 0 status is reported here, it indicates some other issue (e.g. no status from previous middleware)
      # See Rack Spec: https://www.rubydoc.info/github/rack/rack/file/SPEC#label-The+Status
      kvs[:http][:status] = status.to_i

      return unless status.to_i >= 500

      # Because of the 5xx response, we flag this span as errored but
      # without a backtrace (no exception)
      ::Instana.tracer.log_error(nil)
    end

    def add_path_template(kvs, env)
      # If the framework instrumentation provides a path template,
      # pass it into the span here.
      # See: https://www.instana.com/docs/tracing/custom-best-practices/#path-templates-visual-grouping-of-http-endpoints
      kvs[:http][:path_tpl] = env['INSTANA_HTTP_PATH_TEMPLATE'] if env['INSTANA_HTTP_PATH_TEMPLATE']
    end

    def merge_response_headers(kvs, headers)
      extra_response_headers = ::Instana::Util.extra_header_tags(headers)
      if kvs[:http][:header].nil?
        kvs[:http][:header] = extra_response_headers
      else
        kvs[:http][:header].merge!(extra_response_headers)
      end
    end

    def finalize_trace(current_span, kvs, headers, trace_context)
      set_response_headers(headers, trace_context) if headers
      current_span.set_tags(kvs)
      OpenTelemetry::Context.detach(@trace_token) if @trace_token
      current_span.finish
    end

    def set_response_headers(headers, trace_context)
      # Set response headers; encode as hex string
      if trace_context.active?
        headers['X-Instana-T'] = trace_context.trace_id_header
        headers['X-Instana-S'] = trace_context.span_id_header
        headers['X-Instana-L'] = '1'
        headers['Tracestate'] = trace_context.trace_state_header
      else
        headers['X-Instana-L'] = '0'
      end

      headers['Traceparent'] = trace_context.trace_parent_header
      headers['Server-Timing'] = "intid;desc=#{trace_context.trace_id_header}"
    end
  end
end
