
::Instana.logger.warn "Starting background Ruby on Rails #{Rails::VERSION::STRING} application on port 3205"

if Rails::VERSION::STRING >= '5.0' && ::Instana::Test.mysql?
  ::Instana.logger.fatal "Rails 5.x doesn't support the mysql adapter (discontinued).  Set DB_FLAVOR=msyql2 instead.  This will fail as is."
end

require "rails/all"
require "action_controller/railtie" # require more if needed
require 'rack/handler/puma'
require File.expand_path(File.dirname(__FILE__) + '/../models/block')

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

unless ActiveRecord::Base.connection.table_exists? 'blocks'
  if Rails::VERSION::STRING < '4.0'
    CreateBlocks.migrate(:up)
  else
    ActiveRecord::Migration.run(CreateBlocks)
  end
end

class RailsTestApp < Rails::Application
  routes.append do
    get "/test/world"              => "test#world"
    get "/test/db"                 => "test#db"
    get "/test/error"              => "test#error"
    get "/test/render_view"        => "test#render_view"
    get "/test/render_partial"     => "test#render_partial"
    get "/test/render_collection"  => "test#render_collection"
    get "/test/render_file"        => "test#render_file"
    get "/test/render_nothing"     => "test#render_nothing"
    get "/test/render_json"        => "test#render_json"
    get "/test/render_xml"         => "test#render_xml"
    get "/test/render_rawbody"     => "test#render_rawbody"
    get "/test/render_js"          => "test#render_js"
    get "/test/render_alternate_layout"        => "test#render_alternate_layout"
    get "/test/render_partial_that_errors"     => "test#render_partial_that_errors"

    get "/api/world" => "socket#world"
    get "/api/error" => "socket#error"
  end

  # Enable cache classes. Production style.
  config.cache_classes = true
  config.eager_load = false

  # uncomment below to display errors
  # config.consider_all_requests_local = true

  config.paths['app/views'].unshift(File.expand_path(File.dirname(__FILE__) + '/../views'))

  config.active_support.deprecation = :stderr

  config.middleware.delete Rack::Lock
  config.middleware.delete ActionDispatch::Flash

  # We need a secret token for session, cookies, etc.
  config.secret_token = "doesntneedtobesecurefortests"
  config.secret_key_base = "blueredaquarossoseven"
end

class TestController < ActionController::Base
  def world
    if ::Rails::VERSION::MAJOR > 4
      render :plain => "Hello test world!"
    else
      render :text => "Hello test world!"
    end
  end

  def db
    white_block = Block.new(:name => 'Part #28349', :color => 'White')
    white_block.save
    found = Block.where(:name => 'Part #28349').first
    found.delete

    if ::Rails::VERSION::MAJOR > 4
      render :plain => "Hello test db!"
    else
      render :text => "Hello test db!"
    end
  end

  def render_view
    @message = "Hello Instana!"
  end

  def render_partial
    @message = "Hello Instana!"
  end

  def render_partial_that_errors
    @message = "Hello Instana!"
  end

  def render_collection
    @blocks = Block.all
  end

  def render_file
    @message = "Hello Instana!"
    render :file => '/etc/issue'
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

  def error
    raise Exception.new("Warning: This is a simulated Error")
  end
end

if ::Rails::VERSION::MAJOR > 4
  class SocketController < ActionController::API
    def world
      if ::Rails::VERSION::MAJOR > 4
        render :plain => "Hello api world!"
      else
        render :text => "Hello api world!"
      end
    end

    def error
      raise Exception.new("Warning: This is a simulated Socket API Error")
    end
  end
end

RailsTestApp.initialize!

# Initialize some blocks so we have stuff to test against.
Block.new(:name => :corner, :color => :blue).save
Block.new(:name => :floor, :color => :green).save

Thread.new do
  Rack::Handler::Puma.run(RailsTestApp.to_app, {:Host => '127.0.0.1', :Port => 3205})
end

sleep(1)
