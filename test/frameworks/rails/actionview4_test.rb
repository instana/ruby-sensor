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
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_nothing
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_nothing'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "Nothing", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_file
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_file'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "/etc/issue", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_json
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_json'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "JSON", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_xml
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_xml'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "XML", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_body
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_rawbody'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "Raw", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_js
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_js'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "Javascript", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_alternate_layout
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_alternate_layout'))

    spans = Instana.processor.queued_spans
    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "layouts/mobile", av_span[:data][:actionview][:name]
    assert_equal :actionview, av_span[:n]
  end

  def test_render_partial
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial'))

    spans = Instana.processor.queued_spans
    assert_equal 4, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)
    render_span = find_first_span_by_name(spans, :render)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal :partial, render_span[:data][:render][:type]
    assert_equal 'message', render_span[:data][:render][:name]
  end

  def test_render_partial_that_errors
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_partial_that_errors'))

    spans = Instana.processor.queued_spans
    assert_equal 4, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)
    render_span = find_first_span_by_name(spans, :render)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal :actionview, av_span[:n]
    assert_equal :render, render_span[:n]
    assert_equal :partial, render_span[:data][:render][:type]
    assert_equal 'syntax_error', render_span[:data][:render][:name]
    assert render_span[:data][:log].key?(:message)
    assert_equal "SyntaxError", render_span[:data][:log][:parameters]
    assert render_span[:error]
    assert render_span[:stack]
  end

  def test_render_collection
    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/render_collection'))

    spans = Instana.processor.queued_spans
    assert_equal 5, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)
    ar_span = find_first_span_by_name(spans, :activerecord)
    render_span = find_first_span_by_name(spans, :render)

    assert_equal :rack, rack_span[:n]
    assert_equal :actioncontroller, ac_span[:n]
    assert_equal :actionview, av_span[:n]
    assert_equal :activerecord, ar_span[:n]
    assert_equal :render, render_span[:n]
    assert_equal :collection, render_span[:data][:render][:type]
    assert_equal 'blocks/block', render_span[:data][:render][:name]
  end
end
