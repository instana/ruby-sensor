module Instana
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      kvs = { :http => {} }
      kvs[:http][:method] = env['REQUEST_METHOD']
      kvs[:http][:url] = ::CGI.unescape(env['PATH_INFO'])

      if env.key?('HTTP_HOST')
        kvs[:http][:host] = env['HTTP_HOST']
      elsif env.key?('SERVER_NAME')
        kvs[:http][:host] = env['SERVER_NAME']
      end

      # Check incoming context
      incoming_context = {}
      if env.key?('HTTP_X_INSTANA_T')
        incoming_context[:trace_id]  = ::Instana.tracer.header_to_id(env['HTTP_X_INSTANA_T'])
        incoming_context[:parent_id] = ::Instana.tracer.header_to_id(env['HTTP_X_INSTANA_S']) if env.key?('HTTP_X_INSTANA_S')
        incoming_context[:level]     = env['HTTP_X_INSTANA_L'] if env.key?('HTTP_X_INSTANA_L')
      end

      ::Instana.tracer.log_start_or_continue(:rack, {}, incoming_context)

      status, headers, response = @app.call(env)

      kvs[:http][:status] = status

      # Save the IDs before the trace ends so we can place
      # them in the response headers in the ensure block
      trace_id = ::Instana.tracer.trace_id
      span_id = ::Instana.tracer.span_id

      [status, headers, response]
    rescue Exception => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      if headers
        # Set reponse headers; encode as hex string
        headers['X-Instana-T'] = ::Instana.tracer.id_to_header(trace_id)
        headers['X-Instana-S'] = ::Instana.tracer.id_to_header(span_id)
      end
      ::Instana.tracer.log_end(:rack, kvs)
    end
  end
end
