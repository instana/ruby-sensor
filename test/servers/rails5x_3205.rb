
# Set the database.  Default is postgresql.
if ENV['DB_FLAVOR'] == 'mysql2'
  Instana.logger.warn "Starting background Rails 5 test stack with a mysql DB on localhost:3205."
  ENV['DATABASE_URL'] = "mysql://root:#{ENV['TRAVIS_MYSQL_PASS']}@#{ENV['TRAVIS_MYSQL_HOST']}:3306/travis_ci_test"
elsif ENV['DB_FLAVOR'] == 'postgresql'
  Instana.logger.warn "Starting background Rails 5 test stack with a postgres DB on localhost:3205."
  ENV['DATABASE_URL'] = "postgresql://postgres:#{ENV['TRAVIS_PSQL_PASS']}@#{ENV['TRAVIS_PSQL_HOST']}:5432/travis_ci_test"
else
  Instana.logger.error "Rails test server.  Unsupported database type: #{ENV['DB_FLAVOR']}"
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

class Rails50App < Rails::Application
  routes.append do
    get "/test/world" => "test#world"
    get "/test/db"    => "test#db"
  end

  # Enable cache classes. Production style.
  config.cache_classes = true
  config.eager_load = false

  # uncomment below to display errors
  # config.consider_all_requests_local = true

  config.active_support.deprecation = :stderr

  config.middleware.delete Rack::Lock
  config.middleware.delete ActionDispatch::Flash

  # We need a secret token for session, cookies, etc.
  config.secret_token = "doesntneedtobesecurefortests"
  config.secret_key_base = "blueredaquarossoseven"
end

class TestController < ActionController::Base
  def world
    render :plain => "Hello test world!"
  end

  def db
    white_block = Block.new(:name => 'Part #28349', :color => 'White')
    white_block.save
    found = Block.where(:name => 'Part #28349').first
    found.delete
    render :plain => "Hello Test Rails DB!"
  end
end

Rails50App.initialize!

Thread.new do
  Rack::Handler::Puma.run(Rails50App.to_app, {:Host => '127.0.0.1', :Port => 3205})
end

sleep(1)
