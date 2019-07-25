require 'test_helper'

class RestClientTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:'rest-client'].is_a?(Hash)
    assert ::Instana.config[:'rest-client'].key?(:enabled)
    assert_equal true, ::Instana.config[:'rest-client'][:enabled]
  end

  def test_basic_get
    clear_all!
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    Instana.tracer.start_or_continue_trace('restclient-test') do
      RestClient.get url
    end

    assert_equal 2, ::Instana.processor.queue_count

    traces = Instana.processor.queued_traces
    rs_trace = traces[0]
    http_trace = traces[1]

    # RestClient trace validation
    assert_equal 3, http_trace.spans.length
    spans = http_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    # Span name validation
    assert first_span.custom?
    assert_equal :"restclient-test", first_span.name
    assert_equal :"rest-client", second_span.name
    assert_equal :"net-http", third_span.name

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]
    # second_span is parent of third_span
    assert_equal second_span.id, third_span[:p]

    # data keys/values
    refute_nil third_span.key?(:data)
    refute_nil third_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", third_span[:data][:http][:url]
    assert_equal "200", third_span[:data][:http][:status]

    # Rack server trace validation
    assert_equal 1, rs_trace.spans.length
    rs_span = rs_trace.spans.to_a[0]

    # Rack server trace should have the same trace ID
    assert_equal http_trace.id, rs_span[:t].to_i
    # Rack server trace should have net-http has parent span
    assert_equal third_span.id, rs_span[:p].to_i

    WebMock.disable_net_connect!
  end
end
