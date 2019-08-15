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

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "TestController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "world", ac_span[:data][:actioncontroller][:action]
  end

  def test_controller_error
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/error'))

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "TestController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "error", ac_span[:data][:actioncontroller][:action]
    assert ac_span.key?(:error)
    assert ac_span.key?(:stack)
    assert_equal "Warning: This is a simulated Error", ac_span[:data][:log][:message]
    assert_equal "Exception", ac_span[:data][:log][:parameters]
  end

  def test_api_controller_reporting
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/api/world'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "SocketController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "world", ac_span[:data][:actioncontroller][:action]
  end

  def test_api_controller_error
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/api/error'))

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "SocketController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "error", ac_span[:data][:actioncontroller][:action]
    assert ac_span.key?(:error)
    assert ac_span.key?(:stack)
    assert_equal "Warning: This is a simulated Socket API Error", ac_span[:data][:log][:message]
    assert_equal "Exception", ac_span[:data][:log][:parameters]
  end

  def test_404
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/404'))

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans[0]

    assert_equal :rack, first_span[:n]
  end
end
