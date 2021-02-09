# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RailsActionViewTest < Minitest::Test
  include Rack::Test::Methods
  APP = Rack::Builder.parse_file('test/support/apps/action_view/config.ru').first

  def app
    APP
  end

  def setup
    clear_all!
  end

  def test_config_defaults
    assert ::Instana.config[:action_view].is_a?(Hash)
    assert ::Instana.config[:action_view].key?(:enabled)
    assert_equal true, ::Instana.config[:action_view][:enabled]
  end

  def test_render_view
    get '/render_view'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Default', span[:data][:actionview][:name]
  end

  def test_render_view_direct
    get '/render_view_direct'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Default', span[:data][:actionview][:name]
  end

  def test_render_nothing
    # `render nothing: true` was removed in 5.1
    skip unless Rails::VERSION::MAJOR <= 5 && Rails::VERSION::MINOR <= 1
    get '/render_nothing'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Nothing', span[:data][:actionview][:name]
  end

  def test_render_file
    get '/render_file'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'test/support/apps/action_view/config.ru', span[:data][:actionview][:name]
  end

  def test_render_json
    get '/render_json'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'JSON', span[:data][:actionview][:name]
  end

  def test_render_xml
    get '/render_xml'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'XML', span[:data][:actionview][:name]
  end

  def test_render_body
    get '/render_rawbody'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Raw', span[:data][:actionview][:name]
  end

  def test_render_js
    get '/render_js'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Javascript', span[:data][:actionview][:name]
  end

  def test_render_alternate_layout
    get '/render_alternate_layout'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'layouts/mobile', span[:data][:actionview][:name]
  end

  def test_render_partial
    get '/render_partial'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :render)

    assert_equal 'message', span[:data][:render][:name]
  end

  def test_render_partial_that_errors
    get '/render_partial_that_errors'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :render)

    assert_equal :partial, span[:data][:render][:type]
    assert_equal 'syntax_error', span[:data][:render][:name]
    assert span[:data][:log].key?(:message)
    assert span[:data][:log][:parameters].include?('SyntaxError')
    assert span[:error]
    assert span[:stack]
  end

  def test_render_collection
    get '/render_collection'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :render)

    assert_equal :collection, span[:data][:render][:type]
    assert_equal 'blocks/block', span[:data][:render][:name]
  end
end
