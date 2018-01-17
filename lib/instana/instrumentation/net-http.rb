require 'net/http'

if defined?(::Net::HTTP) && ::Instana.config[:nethttp][:enabled]
  Net::HTTP.class_eval {

    def request_with_instana(*args, &block)
      if !Instana.tracer.tracing? || !started?
        do_skip = true
        return request_without_instana(*args, &block)
      end

      ::Instana.tracer.log_entry(:'net-http')

      # Send out the tracing context with the request
      request = args[0]

      # Set request headers; encode IDs as hexadecimal strings
      t_context = ::Instana.tracer.context
      request['X-Instana-T'] = t_context.trace_id_header
      request['X-Instana-S'] = t_context.span_id_header

      # Collect up KV info now in case any exception is raised
      kv_payload = { :http => {} }
      kv_payload[:http][:method] = request.method

      if request.uri
        kv_payload[:http][:url] = request.uri.to_s
      else
        if use_ssl?
          kv_payload[:http][:url] = "https://#{@address}:#{@port}#{request.path}"
        else
          kv_payload[:http][:url] = "http://#{@address}:#{@port}#{request.path}"
        end
      end

      # The core call
      response = request_without_instana(*args, &block)

      # Debug only check: Pickup response headers; convert back to base 10 integer and validate
      if ::Instana.debug? && response.key?('X-Instana-T')
        if ::Instana.tracer.trace_id != ::Instana::Util.header_to_id(response.header['X-Instana-T'])
          ::Instana.logger.debug "#{Thread.current}: Trace ID mismatch on net/http response! ours: #{::Instana.tracer.trace_id} theirs: #{their_trace_id}"
        end
      end

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

    Instana.logger.info "Instrumenting Net::HTTP"

    alias request_without_instana request
    alias request request_with_instana
  }
end
