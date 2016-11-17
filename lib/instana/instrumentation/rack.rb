module Instana
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      req = ::Rack::Request.new(env)
      kvs = { :http => {} }
      kvs[:http][:method] = req.request_method
      kvs[:http][:url] = ::CGI.unescape(req.path)
      ::Instana.tracer.log_start_or_continue(:rack)

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
