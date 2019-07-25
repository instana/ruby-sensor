# Note: We really only need "cgi/util" here but Ruby 2.4.1 has an issue:
# https://bugs.ruby-lang.org/issues/13539
require "cgi"

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

      if ENV.key?('INSTANA_SERVICE_NAME')
        kvs[:service] = ENV['INSTANA_SERVICE_NAME']
      end

      if ::Instana.agent.extra_headers
        ::Instana.agent.extra_headers.each { |custom_header|
          # Headers are available in this format: HTTP_X_CAPTURE_THIS
          rack_header = ('HTTP_' + custom_header.upcase).gsub('-', '_')
          if env.key?(rack_header)
            kvs["http.#{custom_header}"] = env[rack_header]
          end
        }
      end

      # Check incoming context
      incoming_context = {}
      if env.key?('HTTP_X_INSTANA_T')
        incoming_context[:trace_id]  = ::Instana::Util.header_to_id(env['HTTP_X_INSTANA_T'])
        incoming_context[:span_id]   = ::Instana::Util.header_to_id(env['HTTP_X_INSTANA_S']) if env.key?('HTTP_X_INSTANA_S')
        incoming_context[:level]     = env['HTTP_X_INSTANA_L'] if env.key?('HTTP_X_INSTANA_L')
      end

      ::Instana.tracer.log_start_or_continue(:rack, {}, incoming_context)

      status, headers, response = @app.call(env)

      if ::Instana.tracer.tracing?
        kvs[:http][:status] = status

        if !status.is_a?(Integer) || status.between?(500, 511)
          # Because of the 5xx response, we flag this span as errored but
          # without a backtrace (no exception)
          ::Instana.tracer.log_error(nil)
        end

        # Save the IDs before the trace ends so we can place
        # them in the response headers in the ensure block
        trace_id = ::Instana.tracer.trace_id
        span_id = ::Instana.tracer.span_id
      end

      [status, headers, response]
    rescue Exception => e
      ::Instana.tracer.log_error(e)
      raise
    ensure
      if headers && ::Instana.tracer.tracing?
        # Set reponse headers; encode as hex string
        headers['X-Instana-T'] = ::Instana::Util.id_to_header(trace_id)
        headers['X-Instana-S'] = ::Instana::Util.id_to_header(span_id)
      end
      ::Instana.tracer.log_end(:rack, kvs)
    end
  end
end
