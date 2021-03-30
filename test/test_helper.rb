# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

ENV['INSTANA_TEST'] = 'true'

begin
  require 'simplecov'
  require 'simplecov_json_formatter'

  SimpleCov.start do
    enable_coverage :branch

    add_filter %r{^/test/}

    add_group(
      'In Process Collector',
      [%r{lib/instana/(agent|backend|tracing|collectors|open_tracing|snapshot)}, %r{lib/instana/[^/]+\.rb}]
    )

    if ENV['APPRAISAL_INITIALIZED']
      add_group(
        'Instrumentation',
        %r{lib/instana/(activators|frameworks|instrumentation)}
      )
    else
      add_filter %r{lib/instana/(activators|frameworks|instrumentation)}
    end

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
require 'fakefs/safe'

require 'webmock/minitest'
# Webmock: Whitelist local IPs
WebMock.disable_net_connect!(
  allow: ->(uri) { %w[localhost 127.0.0.1 172.17.0.1 172.0.12.100].include?(uri.host) }
)

Dir['test/support/*.rb'].each { |f| load(f) }

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new
Minitest::Test.include(Instana::TestHelpers)
