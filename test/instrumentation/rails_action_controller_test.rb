require 'test_helper'

class RailsActionControllerTest < Minitest::Test
  include Rack::Test::Methods
  APP = Rack::Builder.parse_file('test/support/apps/action_controller/config.ru').first

  def app
    APP
  end

  def test_config_defaults
    assert ::Instana.config[:action_controller].is_a?(Hash)
    assert ::Instana.config[:action_controller].key?(:enabled)
    assert_equal true, ::Instana.config[:action_controller][:enabled]
  end

  def test_controller_reporting
    clear_all!

    get '/base/world'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "TestBaseController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "world", ac_span[:data][:actioncontroller][:action]
  end

  def test_controller_error
    clear_all!

    get '/base/error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "TestBaseController", ac_span[:data][:actioncontroller][:controller]
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

    get '/api/world'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal :actioncontroller, ac_span[:n]
    assert_equal "TestApiController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "world", ac_span[:data][:actioncontroller][:action]
  end

  def test_api_controller_error
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    get '/api/error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal "TestApiController", ac_span[:data][:actioncontroller][:controller]
    assert_equal "error", ac_span[:data][:actioncontroller][:action]
    assert ac_span.key?(:error)
    assert ac_span.key?(:stack)
    assert_equal "Warning: This is a simulated Socket API Error", ac_span[:data][:log][:message]
    assert_equal "Exception", ac_span[:data][:log][:parameters]
  end

  def test_api_controller_not_found
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    get '/api/thispathdoesnotexist'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rack_span = find_first_span_by_name(spans, :rack)

    assert_equal false, rack_span.key?(:error)
    assert_equal "/api/thispathdoesnotexist", rack_span[:data][:http][:url]
    assert_equal 404, rack_span[:data][:http][:status]
    assert_equal "GET", rack_span[:data][:http][:method]
  end

  def test_api_controller_raise_routing_error
    # Run only when ActionController::API is used/defined
    skip unless defined?(::ActionController::API)

    clear_all!

    get '/api/raise_route_error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal false, rack_span.key?(:error)
    assert_equal "/api/raise_route_error", rack_span[:data][:http][:url]
    assert_equal 404, rack_span[:data][:http][:status]
    assert_equal "GET", rack_span[:data][:http][:method]

    assert_equal true, ac_span[:error]
    assert ac_span.key?(:stack)
    assert 1, ac_span[:ec]
  end

  def test_not_found
    clear_all!

    get '/base/404'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rack_span = find_first_span_by_name(spans, :rack)

    assert_equal false, rack_span.key?(:error)
    assert_equal 404, rack_span[:data][:http][:status]
  end

  def test_raise_routing_error
    clear_all!

    get '/base/raise_route_error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)

    assert_equal false, rack_span.key?(:error)
    assert_equal 404, rack_span[:data][:http][:status]

    assert_equal true, ac_span[:error]
    assert ac_span.key?(:stack)
    assert 1, ac_span[:ec]
  end

  def test_path_template
    clear_all!

    get '/base/world'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    rack_span = find_first_span_by_name(spans, :rack)

    assert_equal false, rack_span.key?(:error)
    assert_equal '/base/world(.:format)', rack_span[:data][:http][:path_tpl]
  end
end
