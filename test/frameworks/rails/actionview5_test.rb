require 'test_helper'

class ActionViewTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:action_view].is_a?(Hash)
    assert ::Instana.config[:action_view].key?(:enabled)
    assert_equal true, ::Instana.config[:action_view][:enabled]
  end

  def test_render_view
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_view'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    assert_equal 3, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal :actionview, third_span.name
  end

  def test_render_partial
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    assert_equal 4, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]
    fourth_span = spans[3]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal :actionview, third_span.name
    assert_equal :render, fourth_span.name
    assert_equal :partial, fourth_span[:data][:render][:type]
    assert_equal 'message', fourth_span[:data][:render][:name]
  end

  def test_render_partial_that_errors
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial_that_errors'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    assert_equal 4, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]
    fourth_span = spans[3]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal :actionview, third_span.name
    assert_equal :render, fourth_span.name
    assert_equal :partial, fourth_span[:data][:render][:type]
    assert_equal 'syntax_error', fourth_span[:data][:render][:name]
  end

  def test_render_collection
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_collection'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    assert_equal 5, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]
    fourth_span = spans[3]
    fifth_span = spans[4]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name


    if Rails::VERSION::STRING < '4.0'
      assert_equal :activerecord, third_span.name
      assert_equal :actionview, fourth_span.name
    else
      assert_equal :actionview, third_span.name
      assert_equal :activerecord, fourth_span.name
    end

    assert_equal :render, fifth_span.name
    assert_equal :collection, fifth_span[:data][:render][:type]
    # FIXME - under Rails 5, the collection template isn't being
    # captured properly
    unless Rails::VERSION::MAJOR == 5
      assert_equal 'blocks/block', fifth_span[:data][:render][:name]
    end
  end
end

