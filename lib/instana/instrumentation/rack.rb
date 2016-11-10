module Instana
  class Rack
    def initialize(app)
      @app = app
    end

    def call(env)
      ::Instana.tracer.log_start_or_continue(:rack)

      @app.call(env)
    rescue Exception => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_end(:rack)
    end
  end
end
