require 'test_helper'

class ActionControllerTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:action_controller].is_a?(Hash)
    assert ::Instana.config[:action_controller].key?(:enabled)
    assert_equal true, ::Instana.config[:action_controller][:enabled]
  end

  def test_controller_reporting
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/world'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 3, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :rack, first_span.name

    assert_equal :actioncontroller, second_span.name
    assert_equal "TestController", second_span[:data][:actioncontroller][:controller]
    assert_equal "world", second_span[:data][:actioncontroller][:action]
  end

  def test_controller_error
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/error'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 2, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :rack, first_span.name

    assert_equal :actioncontroller, second_span.name
    assert_equal "TestController", second_span[:data][:actioncontroller][:controller]
    assert_equal "error", second_span[:data][:actioncontroller][:action]
    assert second_span.key?(:error)
    assert second_span.key?(:stack)
    assert_equal "Warning: This is a simulated Error", second_span[:data][:log][:message]
    assert_equal "Exception", second_span[:data][:log][:parameters]
  end

  def test_api_controller_reporting
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/api/world'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 3, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :rack, first_span.name

    assert_equal :actioncontroller, second_span.name
    assert_equal "SocketController", second_span[:data][:actioncontroller][:controller]
    assert_equal "world", second_span[:data][:actioncontroller][:action]
  end

  def test_api_controller_error
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/api/error'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 2, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :rack, first_span.name

    assert_equal :actioncontroller, second_span.name
    assert_equal "SocketController", second_span[:data][:actioncontroller][:controller]
    assert_equal "error", second_span[:data][:actioncontroller][:action]
    assert second_span.key?(:error)
    assert second_span.key?(:stack)
    assert_equal "Warning: This is a simulated Socket API Error", second_span[:data][:log][:message]
    assert_equal "Exception", second_span[:data][:log][:parameters]
  end

  def test_404
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/404'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 1, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]

    assert_equal :rack, first_span.name
  end
end
