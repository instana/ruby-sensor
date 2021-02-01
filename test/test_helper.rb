ENV['INSTANA_TEST'] = 'true'

begin
  require 'simplecov'
  require 'simplecov_json_formatter'

  SimpleCov.start do
    enable_coverage :branch

    add_group 'Frameworks', 'lib/instana/frameworks'
    add_group 'Instrumentation', 'lib/instana/instrumentation'

    add_filter %r{^/test/}

    if ENV['CI']
      formatter SimpleCov::Formatter::JSONFormatter
    end
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

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new
Minitest::Test.include(Instana::TestHelpers)
