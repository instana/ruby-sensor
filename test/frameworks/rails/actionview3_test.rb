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

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal :actionview, third_span.name
  end

  def test_render_nothing
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_nothing'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "Nothing", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_file
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_file'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "/etc/issue", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_json
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_json'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "JSON", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_xml
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_xml'))

    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "XML", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_body
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_rawbody'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "Raw", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_js
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_js'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "Javascript", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_alternate_layout
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_alternate_layout'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal "layouts/mobile", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span.name
  end

  def test_render_partial
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial'))

    spans = Instana.processor.queued_spans
    assert_equal 4, spans.length
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

    spans = Instana.processor.queued_spans
    assert_equal 4, spans.length
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
    assert fourth_span[:data][:log].key?(:message)
    assert_equal "ActionView::Template::Error", fourth_span[:data][:log][:parameters]
    assert fourth_span[:error]
    assert fourth_span[:stack]
  end

  def test_render_collection
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_collection'))

    spans = Instana.processor.queued_spans
    assert_equal 5, spans.length
    first_span = spans[0]
    second_span = spans[1]
    third_span = spans[2]
    fourth_span = spans[3]
    fifth_span = spans[4]

    assert_equal :rack, first_span.name
    assert_equal :actioncontroller, second_span.name
    assert_equal :activerecord, third_span.name
    assert_equal :actionview, fourth_span.name

    assert_equal :render, fifth_span.name
    assert_equal :collection, fifth_span[:data][:render][:type]
    assert_equal 'blocks/block', fifth_span[:data][:render][:name]
  end
end
