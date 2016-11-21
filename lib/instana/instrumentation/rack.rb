module Instana
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      kvs = { :http => {} }
      kvs[:http][:method] = env['REQUEST_METHOD']
      kvs[:http][:url] = ::CGI.unescape(env['PATH_INFO'])

      # Check incoming context
      incoming_context = {}
      if env.key?('HTTP_X_INSTANA_T')
        incoming_context[:trace_id]  = env['HTTP_X_INSTANA_T']
        incoming_context[:parent_id] = env['HTTP_X_INSTANA_S'] if env.key?('HTTP_X_INSTANA_S')
        incoming_context[:level]     = env['HTTP_X_INSTANA_L'] if env.key?('HTTP_X_INSTANA_L')
      end

      ::Instana.tracer.log_start_or_continue(:rack, {}, incoming_context)

      status, headers, response = @app.call(env)

      kvs[:http][:status] = status

      [status, headers, response]
    rescue Exception => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_end(:rack, kvs)
    end
  end
end
