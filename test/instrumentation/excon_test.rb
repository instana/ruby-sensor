require 'test_helper'

class ExconTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:excon].is_a?(Hash)
    assert ::Instana.config[:excon].key?(:enabled)
    assert_equal true, ::Instana.config[:excon][:enabled]
  end

  def test_basic_get
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6511"

    connection = Excon.new(url)
    Instana.tracer.start_or_continue_trace('excon-test') do
      connection.get(:path => '/?basic_get')
    end

    traces = Instana.processor.queued_traces
    assert_equal 2, traces.length
    rs_trace = traces[0]
    http_trace = traces[1]

    # Excon validation
    assert_equal 2, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :"excon-test", first_span[:data][:sdk][:name]
    assert_equal :excon, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", second_span[:data][:http][:url]
    assert_equal 200, second_span[:data][:http][:status]

    # excon backtrace not included by default check
    assert !second_span.key?(:stack)

    # Rack server trace validation
    assert_equal 1, rs_trace.spans.length
    rs_span = rs_trace.spans.to_a[0]

    # Rack server trace should have the same trace ID
    assert_equal http_trace.id, rs_span[:t].to_i
    assert_equal rs_span[:p].to_i, second_span[:s]
  end

  def test_basic_get_with_error
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6500"

    begin
      connection = Excon.new(url)
      Instana.tracer.start_or_continue_trace('excon-test') do
        connection.get(:path => '/?basic_get')
      end
    rescue
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    http_trace = traces.first

    # Excon validation
    assert_equal 2, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :"excon-test", first_span[:data][:sdk][:name]
    assert_equal :excon, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6500/", second_span[:data][:http][:url]
    assert_equal nil, second_span[:data][:http][:status]

    # excon span should include an error backtrace
    assert second_span.key?(:stack)

    # error validation
    assert_equal true, second_span[:error]
    #assert_equal 1, second_span[:ec]
  end

  def test_pipelined_requests
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6511"

    connection = Excon.new(url)
    request = { :method => :get, :path => '/?pipelined_request' }
    Instana.tracer.start_or_continue_trace('excon-test') do
      connection.requests([request, request, request])
    end

    traces = Instana.processor.queued_traces
    assert_equal 4, traces.length
    http_trace = traces[3]

    # Excon validation
    assert_equal 4, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]
    fourth_span = spans[3]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :"excon-test", first_span[:data][:sdk][:name]
    assert_equal :excon, second_span[:n]
    assert_equal :excon, third_span[:n]
    assert_equal :excon, fourth_span[:n]

    # first_span is the parent of second/third/fourth_span
    assert_equal first_span.id, second_span[:p]
    assert_equal first_span.id, third_span[:p]
    assert_equal first_span.id, fourth_span[:p]

    # data keys/values
    refute_nil second_span.key?(:data)
    refute_nil second_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", second_span[:data][:http][:url]
    assert_equal 200, second_span[:data][:http][:status]
    assert !second_span.key?(:stack)

    refute_nil third_span.key?(:data)
    refute_nil third_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", third_span[:data][:http][:url]
    assert_equal 200, third_span[:data][:http][:status]
    assert !third_span.key?(:stack)

    refute_nil fourth_span.key?(:data)
    refute_nil fourth_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", fourth_span[:data][:http][:url]
    assert_equal 200, fourth_span[:data][:http][:status]
    assert !fourth_span.key?(:stack)
  end
end
