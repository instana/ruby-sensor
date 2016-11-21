require 'test_helper'

class NetHTTPTest < Minitest::Test
  def test_basic_get
    WebMock.allow_net_connect!
    url = "http://www.instana.com"
    #stub_request(:get, url).to_return(:status => 200)

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)

    response = nil
    Instana.tracer.start_or_continue_trace('net-http-test') do
      Net::HTTP.start(req.uri.hostname, req.uri.port, :open_timeout => 1, :read_timeout => 1) do |http|
        response = http.request(req)
      end
    end

    assert_equal 1, ::Instana.processor.queue_count
    t = Instana.processor.queued_traces.first
    assert_equal 2, t.spans.count
    spans = t.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal 'net-http-test', first_span[:n]
    assert_equal :net_http, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]
    WebMock.disable_net_connect!
  end

  def test_request_with_error
    skip
    WebMock.allow_net_connect!
    url = "http://doesnotresolve.asdfasdf"

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)

    begin
      response = nil
      Instana.tracer.start_or_continue_trace('net-http-error-test') do
        Net::HTTP.start(req.uri.hostname, req.uri.port, :open_timeout => 1, :read_timeout => 1) do |http|
          response = http.request(req)
        end
      end
    rescue
      # We are raising an exception on purpose - do nothing
    end

    assert_equal 1, ::Instana.processor.queue_count
    t = Instana.processor.queued_traces.first
    assert_equal 2, t.spans.count
    assert t.has_error?
    spans = t.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal 'net-http-test', first_span[:n]
    assert_equal :net_http, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]
    WebMock.disable_net_connect!
  end
end
