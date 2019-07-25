require 'test_helper'

class NetHTTPTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:nethttp].is_a?(Hash)
    assert ::Instana.config[:nethttp].key?(:enabled)
    assert_equal true, ::Instana.config[:nethttp][:enabled]
  end

  def test_block_request
    clear_all!
    WebMock.allow_net_connect!
    url = "http://127.0.0.1:6511/"

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)

    response = nil
    Instana.tracer.start_or_continue_trace('net-http-test') do
      Net::HTTP.start(req.uri.hostname, req.uri.port, :open_timeout => 1, :read_timeout => 1) do |http|
        response = http.request(req)
      end
    end

    assert_equal 2, ::Instana.processor.queue_count

    traces = Instana.processor.queued_traces
    rs_trace = traces[0]
    http_trace = traces[1]

    # Net::HTTP trace validation
    assert_equal 2, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :'net-http', second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", second_span[:data][:http][:url]
    assert_equal "200", second_span[:data][:http][:status]
    assert !second_span.key?(:stack)

    # Rack server trace validation
    assert_equal 1, rs_trace.spans.length
    rs_span = rs_trace.spans.to_a[0]

    # Rack server trace should have the same trace ID
    assert_equal http_trace.id, rs_span[:t].to_i
    # Rack server trace should have net-http has parent span
    assert_equal second_span.id, rs_span[:p].to_i

    WebMock.disable_net_connect!
  end

  def test_basic_post_without_uri
    clear_all!
    WebMock.allow_net_connect!

    response = nil
    Instana.tracer.start_or_continue_trace('net-http-test') do
      http = Net::HTTP.new("127.0.0.1", 6511)
      response = http.request(Net::HTTP::Post.new("/"))
    end

    assert_equal 2, ::Instana.processor.queue_count

    traces = Instana.processor.queued_traces
    rs_trace = traces[0]
    http_trace = traces[1]

    # Net::HTTP trace validation
    assert_equal 2, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :'net-http', second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", second_span[:data][:http][:url]
    assert_equal "200", second_span[:data][:http][:status]
    assert !second_span.key?(:stack)

    # Rack server trace validation
    assert_equal 1, rs_trace.spans.length
    rs_span = rs_trace.spans.to_a[0]

    # Rack server trace should have the same trace ID
    assert_equal http_trace.id, rs_span[:t].to_i
    # Rack server trace should have net-http has parent span
    assert_equal second_span.id, rs_span[:p].to_i

    WebMock.disable_net_connect!
  end

  def test_request_with_dns_error
    clear_all!
    WebMock.allow_net_connect!

    begin
      Instana.tracer.start_or_continue_trace('net-http-error-test') do
        http = Net::HTTP.new("asdfasdf.asdfsadf", 80)
        http.request(Net::HTTP::Get.new("/blah"))
      end
    rescue Exception
      nil
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    t = traces[0]
    assert_equal 1, t.spans.count
    assert t.has_error?
    spans = t.spans.to_a
    first_span = spans[0]

    assert_equal :'net-http-error-test', first_span.name
    assert first_span.custom?
    ts_key = first_span[:data][:sdk][:custom][:logs].keys.first
    assert first_span[:data][:sdk][:custom][:logs].key?(ts_key)
    assert first_span[:data][:sdk][:custom][:logs][ts_key].key?(:event)
    assert first_span[:data][:sdk][:custom][:logs][ts_key].key?(:parameters)

    WebMock.disable_net_connect!
  end

  def test_request_with_5xx_response
    clear_all!
    WebMock.allow_net_connect!

    response = nil
    Instana.tracer.start_or_continue_trace('net-http-error-test') do
      http = Net::HTTP.new("127.0.0.1", 6511)
      response = http.request(Net::HTTP::Get.new("/error"))
    end

    traces = Instana.processor.queued_traces
    assert_equal 2, traces.length

    request_trace = traces[1]
    assert_equal 2, request_trace.spans.length
    assert request_trace.has_error?
    http_span = request_trace.spans.to_a[1]

    refute_nil http_span.key?(:data)
    refute_nil http_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/error", http_span[:data][:http][:url]
    assert_equal "500", http_span[:data][:http][:status]
    assert_equal :'net-http', http_span.name
    assert !http_span.key?(:stack)

    WebMock.disable_net_connect!
  end
end
