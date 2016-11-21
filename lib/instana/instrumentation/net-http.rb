require 'net/http'

Net::HTTP.class_eval {

  def request_with_instana(*args, &block)
    if !Instana.tracer.tracing? || !started?
      return request_without_instana(*args, &block)
    end

    ::Instana.tracer.log_entry(:net_http)

    # Send out the tracing context with the request
    request = args[0]
    our_trace_id = ::Instana.tracer.trace_id

    #TODO add host agent to blacklist

    request['X-Instana-T'] = our_trace_id
    request['X-Instana-S'] = ::Instana.tracer.span_id

    response = request_without_instana(*args, &block)

    # Pickup response headers
    their_trace_id = response.get_fields('X-Instana-T')
    their_span_id = response.get_fields('X-Instana-S')

    if their_trace_id && our_trace_id != their_trace_id
      ::Instana.logger.debug "Trace ID mismatch on net/http response! ours: #{our_trace_id} theirs: #{their_trace_id}"
    end

    response
  rescue => e
    ::Instana.tracer.log_error(e)
    raise
  ensure
    ::Instana.tracer.log_exit(:net_http)
  end

  Instana.logger.info "Instrumenting net/http"

  alias request_without_instana request
  alias request request_with_instana
}
