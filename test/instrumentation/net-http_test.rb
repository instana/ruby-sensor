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

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rs_span = find_first_span_by_name(spans, :rack)
    first_span = find_first_span_by_name(spans, :'net-http-test')
    second_span = find_first_span_by_name(spans, :'net-http')

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :'net-http', second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span[:s], second_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", second_span[:data][:http][:url]
    assert_equal "200", second_span[:data][:http][:status]
    assert !second_span.key?(:stack)

    # Rack server trace should have the same trace ID
    assert_equal rs_span[:t], first_span[:t]
    assert_equal first_span[:t], second_span[:t]

    # Rack server trace should have net-http has parent span
    assert_equal second_span[:s], rs_span[:p]

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

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    sdk_span = find_first_span_by_name(spans, :'net-http-test')
    http_span = find_first_span_by_name(spans, :'net-http')

    # Span name validation
    assert_equal :sdk, sdk_span[:n]
    assert_equal :'net-http', http_span[:n]

    # first_span is the parent of second_span
    assert_equal sdk_span[:s], http_span[:p]

    # data keys/values
    refute_nil http_span.key?(:data)
    refute_nil http_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", http_span[:data][:http][:url]
    assert_equal "200", http_span[:data][:http][:status]
    assert !http_span.key?(:stack)

    # Rack server trace should have the same trace ID
    assert_equal rack_span[:t], sdk_span[:t]
    assert_equal sdk_span[:t], http_span[:t]

    # Rack server trace should have net-http has parent span
    assert_equal http_span[:s], rack_span[:p]

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

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans.first

    assert_equal :sdk, first_span[:n]
    assert_equal :'net-http-error-test', first_span[:data][:sdk][:name]
    assert_equal true, first_span[:error]
    assert_equal 1, first_span[:ec]
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

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    sdk_span = find_first_span_by_name(spans, :'net-http-error-test')
    http_span = find_first_span_by_name(spans, :'net-http')

    assert_equal :sdk, sdk_span[:n]
    assert_equal :'net-http-error-test', sdk_span[:data][:sdk][:name]
    assert_equal nil, sdk_span[:error]
    assert_equal nil, sdk_span[:ec]

    refute_nil http_span.key?(:data)
    refute_nil http_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/error", http_span[:data][:http][:url]
    assert_equal "500", http_span[:data][:http][:status]
    assert_equal :'net-http', http_span[:n]
    assert !http_span.key?(:stack)
    assert_equal true, http_span[:error]
    assert_equal 1, http_span[:ec]

    WebMock.disable_net_connect!
  end
end
