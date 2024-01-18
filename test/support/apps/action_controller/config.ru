# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'rails'
require 'action_controller/railtie'

class TestControllerApplication < Rails::Application
  config.eager_load = 'test'
  config.consider_all_requests_local = false
  config.secret_key_base = 'test_key'
  config.secret_token = 'test_token'

  if Rails::VERSION::MAJOR > 5
    config.hosts.clear
  end

  routes.append do
    get '/base/world' => 'test_base#world'
    get '/base/raise_route_error' => 'test_base#raise_route_error'
    get '/base/error' => 'test_base#error'
    get '/base/log_warning' => 'test_base#log_warning'

    if defined?(::ActionController::API)
      get '/api/world' => 'test_api#world'
      get '/api/error' => 'test_api#error'
      get '/api/raise_route_error' => 'test_api#raise_route_error'
    end
  end
end

class TestBaseController < ActionController::Base
  def world
    render plain: 'Hello world!'
  end

  def raise_route_error
    raise ActionController::RoutingError, 'Simulated not found'
  end

  def error
    raise StandardError, "Warning: This is a simulated Error"
  end

  def log_warning
    Rails.logger.warn "This is a test warning"
    render plain: 'Test warning logged'
  end
end

if defined?(::ActionController::API)
  class TestApiController < ActionController::API
    def world
      render plain: 'Hello world!'
    end

    def raise_route_error
      raise ActionController::RoutingError, 'Simulated not found'
    end

    def error
      raise StandardError, "Warning: This is a simulated Socket API Error"
    end
  end
end

TestControllerApplication.initialize!

run TestControllerApplication
