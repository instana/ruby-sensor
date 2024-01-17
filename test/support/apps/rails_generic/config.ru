# (c) Copyright IBM Corp. 2024

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
    get '/base/log_warning' => 'test_base#log_warning'
  end
end

class TestBaseController < ActionController::Base
  def log_warning
    Rails.logger.warn "This is a test warning"
    render plain: 'Test warning logged'
  end
end

TestControllerApplication.initialize!

run TestControllerApplication
