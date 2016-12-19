require 'net/http'

Net::HTTP.class_eval {

  def request_with_instana(*args, &block)
    if !Instana.tracer.tracing? || !started?
      return request_without_instana(*args, &block)
    end

    ::Instana.tracer.log_entry(:'net-http')

    # Send out the tracing context with the request
    request = args[0]

    # Set request headers; encode IDs as hexadecimal strings
    request['X-Instana-T'] = ::Instana.tracer.trace_id_header
    request['X-Instana-S'] = ::Instana.tracer.span_id_header

    response = request_without_instana(*args, &block)

    # Pickup response headers; convert back to base 10 integer
    if ::Instana.debug? && response.key?('X-Instana-T')
      their_trace_id = ::Instana.tracer.header_to_id(response.header['X-Instana-T'])
      if ::Instana.tracer.trace_id != their_trace_id
        ::Instana.logger.debug "#{Thread.current}: Trace ID mismatch on net/http response! ours: #{::Instana.tracer.trace_id} theirs: #{their_trace_id}"
      end
    end

    kv_payload = { :http => {} }
    kv_payload[:http][:status] = response.code
    kv_payload[:http][:url] = request.uri.to_s
    kv_payload[:http][:method] = request.method
    ::Instana.tracer.log_info(kv_payload)

    response
  rescue => e
    ::Instana.tracer.log_error(e)
    raise
  ensure
    ::Instana.tracer.log_exit(:'net-http')
  end

  Instana.logger.warn "Instrumenting Net::HTTP"

  alias request_without_instana request
  alias request request_with_instana
}
