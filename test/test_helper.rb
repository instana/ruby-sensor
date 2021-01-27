ENV['INSTANA_TEST'] = 'true'

begin
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch

    add_group 'Frameworks', 'lib/instana/frameworks'
    add_group 'Instrumentation', 'lib/instana/instrumentation'
  end
rescue LoadError => _e
  nil
end

require 'bundler/setup'
Bundler.require

require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"

require 'webmock/minitest'
# Webmock: Whitelist local IPs
WebMock.disable_net_connect!(
  allow: ->(uri) { %w[localhost 127.0.0.1 172.17.0.1 172.0.12.100].include?(uri.host) }
)

Dir['test/support/*.rb'].each { |f| load(f) }

require "instana/test"
::Instana::Test.setup_environment

# Boot background webservers to test against.
require "./test/servers/rackapp_6511"

case File.basename(ENV['BUNDLE_GEMFILE'])
when /rails/
  require './test/servers/rails_3205'
when /grpc/
  # Configure gRPC
  require './test/servers/grpc_50051.rb'
when /sidekiq/
  # Hook into sidekiq to control the current mode
  $sidekiq_mode = :client
  class << Sidekiq
    def server?
      $sidekiq_mode == :server
    end
  end

  ENV['REDIS_URL'] ||= 'redis://127.0.0.1:6379'

  # Configure redis for sidekiq client
  Sidekiq.configure_client do |config|
    config.redis = { url: ENV['REDIS_URL'] }
  end

  # Configure redis for sidekiq worker
  $sidekiq_mode = :server
  ::Sidekiq.configure_server do |config|
    config.redis = { url: ENV['REDIS_URL'] }
  end
  $sidekiq_mode = :client

  require './test/servers/sidekiq/worker'
end

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

Minitest::Test.include(Instana::TestHelpers)
