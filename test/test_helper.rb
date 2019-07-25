$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
ENV['INSTANA_TEST'] = 'true'
require "rubygems"
require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']
require "minitest/benchmark"
require 'webmock/minitest'

require "instana/test"
::Instana::Test.setup_environment

# Webmock: Whitelist local IPs
whitelist = ['127.0.0.1', 'localhost', '172.17.0.1', '172.0.12.100']
allowed_sites = lambda{|uri|
  whitelist.include?(uri.host)
}
::WebMock.disable_net_connect!(allow: allowed_sites)

# Boot background webservers to test against.
require "./test/servers/rackapp_6511"

case File.basename(ENV['BUNDLE_GEMFILE'])
when /rails50|rails42|rails32/
  require './test/servers/rails_3205'
when /libraries/
  # Configure gRPC
  require './test/servers/grpc_50051.rb'

  # Hook into sidekiq to control the current mode
  $sidekiq_mode = :client
  class << Sidekiq
    def server?
      $sidekiq_mode == :server
    end
  end

  ENV['I_REDIS_URL'] ||= 'redis://127.0.0.1:6379'

  # Configure redis for sidekiq client
  Sidekiq.configure_client do |config|
    config.redis = { url: ENV['I_REDIS_URL'] }
  end

  # Configure redis for sidekiq worker
  $sidekiq_mode = :server
  ::Sidekiq.configure_server do |config|
    config.redis = { url: ENV['I_REDIS_URL'] }
  end
  $sidekiq_mode = :client

  require './test/servers/sidekiq/worker'
end

if defined?(::Redis)
  $redis = Redis.new(url: ENV['I_REDIS_URL'])
end

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

# Used to reset the gem to boot state.  It clears out any queued and/or staged
# traces and resets the tracer to no active trace.
#
def clear_all!
  ::Instana.processor.clear!
  ::Instana.tracer.clear!
  $redis.flushall if $redis
  nil
end

def disable_redis_instrumentation
  ::Redis::Client.class_eval do
    alias call call_without_instana
    alias call_pipeline call_pipeline_without_instana
  end
end

def enable_redis_instrumentation
  ::Redis::Client.class_eval do
    alias call call_with_instana
    alias call_pipeline call_pipeline_with_instana
  end
end
