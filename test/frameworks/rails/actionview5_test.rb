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

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_nothing
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_nothing'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "Nothing", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_file
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_file'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "/etc/issue", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_json
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_json'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "JSON", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_xml
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_xml'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "XML", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_body
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_rawbody'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "Raw", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_js
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_js'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "Javascript", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_alternate_layout
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_alternate_layout'))

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span = spans[2]
    second_span = spans[1]
    third_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal "layouts/mobile", third_span[:data][:actionview][:name]
    assert_equal :actionview, third_span[:n]
  end

  def test_render_partial
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial'))

    spans = ::Instana.processor.queued_spans
    assert_equal 4, spans.length

    first_span = spans[3]
    second_span = spans[2]
    third_span = spans[1]
    fourth_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal :actionview, third_span[:n]
    assert_equal :render, fourth_span[:n]
    assert_equal :partial, fourth_span[:data][:render][:type]
    assert_equal 'message', fourth_span[:data][:render][:name]
  end

  def test_render_partial_that_errors
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial_that_errors'))

    spans = ::Instana.processor.queued_spans
    assert_equal 4, spans.length

    first_span = spans[3]
    second_span = spans[2]
    third_span = spans[1]
    fourth_span = spans[0]

    assert_equal :rack, first_span[:n]
    assert_equal :actioncontroller, second_span[:n]
    assert_equal :actionview, third_span[:n]
    assert_equal :render, fourth_span[:n]
    assert_equal :partial, fourth_span[:data][:render][:type]
    assert_equal 'syntax_error', fourth_span[:data][:render][:name]
    assert fourth_span[:data][:log].key?(:message)
    assert_equal "SyntaxError", fourth_span[:data][:log][:parameters]
    assert fourth_span[:error]
    assert fourth_span[:stack]
  end

  def test_render_collection
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_collection'))

    spans = ::Instana.processor.queued_spans
    assert_equal 5, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    ar_span = find_first_span_by_name(spans, :activerecord)
    av_span = find_first_span_by_name(spans, :actionview)
    render_span = find_first_span_by_name(spans, :render)

    assert_equal render_span[:p], av_span[:s]
    assert_equal av_span[:p], ac_span[:s]
    assert_equal ar_span[:p], av_span[:s]
    assert_equal ac_span[:p], rack_span[:s]

    assert_equal :render, render_span[:n]
    assert_equal :collection, render_span[:data][:render][:type]
    assert_equal 'blocks/block', render_span[:data][:render][:name]
  end
end
