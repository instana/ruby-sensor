require 'test_helper'

class ExconTest < Minitest::Test
  def test_basic_get
    ::Instana.processor.clear!
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    Instana.tracer.start_or_continue_trace('excon-test') do
      Excon.get url
    end

    assert_equal 2, ::Instana.processor.queue_count

    traces = Instana.processor.queued_traces
    rs_trace = traces[0]
    http_trace = traces[1]

    # Excon validation
    assert_equal 2, http_trace.spans.count
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

    # Rack server trace validation
    assert_equal 1, rs_trace.spans.count
    rs_span = rs_trace.spans.to_a[0]

    # Rack server trace should have the same trace ID
    assert_equal http_trace.id, rs_span[:t].to_i
    assert_equal rs_span[:p].to_i, second_span[:s]

    WebMock.disable_net_connect!
  end
end
