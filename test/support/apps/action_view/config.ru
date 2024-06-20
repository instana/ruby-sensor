# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'rails'
require 'action_controller/railtie'

RAILS_VERSION = Gem::Specification.find_by_name('rails').version

class TestViewApplication < Rails::Application
  config.eager_load = 'test'
  config.consider_all_requests_local = true
  config.secret_key_base = 'test_key'
  config.secret_token = 'test_token'
  config.autoload_paths = []
  ActiveSupport::Dependencies.autoload_paths = ActiveSupport::Dependencies.autoload_paths.dup
  ActiveSupport::Dependencies.autoload_once_paths = ActiveSupport::Dependencies.autoload_paths.dup

  if Rails::VERSION::MAJOR > 5
    config.hosts.clear
  end

  routes.append do
      get '/render_view' => 'test_view#render_view'
      get '/render_view_direct' => 'test_view#render_view_direct'
      get '/render_partial' => 'test_view#render_partial'
      get '/render_partial_that_errors' => 'test_view#render_partial_that_errors'
      get '/render_collection' => 'test_view#render_collection'
      get '/render_file' => 'test_view#render_file'
      get '/render_alternate_layout' => 'test_view#render_alternate_layout'
      get '/render_nothing' => 'test_view#render_nothing'
      get '/render_json' => 'test_view#render_json'
      get '/render_xml' => 'test_view#render_xml'
      get '/render_rawbody' => 'test_view#render_rawbody'
      get '/render_js' => 'test_view#render_js'
    end
  end

TestViewObject = Struct.new(:name) do
  def to_partial_path
    'blocks/block'
  end
end

class TestViewController < ActionController::Base
  before_action :prepend_views

  def render_view
    @message = "Hello Instana!"
  end

  def render_view_direct
    @message = "Hello Instana!"
    render "render_view"
  end

  def render_partial
    @message = "Hello Instana!"
  end

  def render_partial_that_errors
    @message = "Hello Instana!"
  end

  def render_collection
    @blocks = [
      TestViewObject.new('Sample')
    ]
  end

  def render_file
    @message = "Hello Instana!"
    render file: "#{__dir__}/config.ru"
  end

  def render_alternate_layout
    @message = "Hello Instana!"
    render :layout => 'layouts/mobile'
  end

  def render_nothing
    @message = "Hello Instana!"
    render :nothing => true
  end

  def render_json
    @message = "Hello Instana!"
    render :json => @message
  end

  def render_xml
    @message = "Hello Instana!"
    render :xml => @message
  end

  def render_rawbody
    @message = "Hello Instana!"
    render :body => 'raw body output'
  end

  def render_js
    @message = "Hello Instana!"
    render :js => @message
  end

  private

  def prepend_views
    prepend_view_path "#{__dir__}/views"
  end
end

TestViewApplication.initialize!
run TestViewApplication
