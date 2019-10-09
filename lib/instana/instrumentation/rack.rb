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
          rack_header = 'HTTP_' + custom_header.upcase
          rack_header.tr!('-', '_')

          if env.key?(rack_header)
            unless kvs[:http].key?(:header)
              kvs[:http][:header] = {}
            end
            kvs[:http][:header][custom_header.to_sym] = env[rack_header]
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

        # Save the IDs before the trace ends so we can place
        # them in the response headers in the ensure block
        trace_id = ::Instana.tracer.current_span.trace_id
        span_id = ::Instana.tracer.current_span.id
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
