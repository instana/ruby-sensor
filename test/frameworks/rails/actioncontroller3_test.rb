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
    assert_equal 1, traces.count
    trace = traces.first

    ::Instana::Util.pry!
    assert_equal 2, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :rack, first_span.name

    assert_equal :actioncontroller, second_span.name
    assert_equal "TestController", second_span[:data][:actioncontroller][:controller]
    assert_equal "world", second_span[:data][:actioncontroller][:action]
  end
end
