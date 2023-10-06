# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RailsActionViewTest < Minitest::Test
  include Rack::Test::Methods
  APP = Rack::Builder.parse_file('test/support/apps/action_view/config.ru')
  railties_version = Gem::Specification.find_by_name('railties').version
  if railties_version < Gem::Version.new('7.1.0')
    APP = APP.first
  end

  def app
    APP
  end

  def setup
    clear_all!
    @framework_version = Gem::Specification.find_by_name('rails').version
    @supported_framework_version = @framework_version < Gem::Version.new('6.1')
    @execute_test_if_framework_version_is_supported = lambda {
      unless @supported_framework_version
        skip "Skipping this test because Rails version #{@framework_version} is not yet supported!"
      end
    }
    @execute_test_only_if_framework_version_is_not_supported = lambda {
      if @supported_framework_version
        skip "Skipping this test because Rails version #{@framework_version} is already supported!"
      end
    }
  end

  def test_config_defaults
    assert ::Instana.config[:action_view].is_a?(Hash)
    assert ::Instana.config[:action_view].key?(:enabled)
    assert_equal true, ::Instana.config[:action_view][:enabled]
  end

  def test_no_tracing_if_unsupported_version_only_render_is_ok
    @execute_test_only_if_framework_version_is_not_supported.call

    ['/render_view', '/render_view_direct', '/render_partial', '/render_collection', '/render_file',
     '/render_alternate_layout', '/render_json', '/render_xml',
     '/render_rawbody', '/render_js'].each do |endpoint|
      get endpoint
      assert last_response.ok?
    end

    get '/render_partial_that_errors'
    assert_equal false, last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal [], spans
  end

  def test_render_view
    @execute_test_if_framework_version_is_supported.call
    get '/render_view'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Default', span[:data][:actionview][:name]
  end

  def test_render_view_direct
    @execute_test_if_framework_version_is_supported.call
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
    @execute_test_if_framework_version_is_supported.call
    get '/render_file'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'test/support/apps/action_view/config.ru', span[:data][:actionview][:name]
  end

  def test_render_json
    @execute_test_if_framework_version_is_supported.call
    get '/render_json'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'JSON', span[:data][:actionview][:name]
  end

  def test_render_xml
    @execute_test_if_framework_version_is_supported.call
    get '/render_xml'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'XML', span[:data][:actionview][:name]
  end

  def test_render_body
    @execute_test_if_framework_version_is_supported.call
    get '/render_rawbody'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Raw', span[:data][:actionview][:name]
  end

  def test_render_js
    @execute_test_if_framework_version_is_supported.call
    get '/render_js'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'Javascript', span[:data][:actionview][:name]
  end

  def test_render_alternate_layout
    @execute_test_if_framework_version_is_supported.call
    get '/render_alternate_layout'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :actionview)

    assert_equal 'layouts/mobile', span[:data][:actionview][:name]
  end

  def test_render_partial
    @execute_test_if_framework_version_is_supported.call
    get '/render_partial'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :render)

    assert_equal 'message', span[:data][:render][:name]
  end

  def test_render_partial_that_errors
    @execute_test_if_framework_version_is_supported.call
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
    @execute_test_if_framework_version_is_supported.call
    get '/render_collection'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :render)

    assert_equal :collection, span[:data][:render][:type]
    assert_equal 'blocks/block', span[:data][:render][:name]
  end
end
