# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

ENV['INSTANA_TEST'] = 'true'

begin
  require 'simplecov'
  require 'simplecov_json_formatter'
  require 'simplecov-json'

  SimpleCov.start do
   


    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::JSONFormatter
      ]
    )
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
  allow: ->(uri) { %w[localhost 127.0.0.1 172.17.0.1 172.0.12.100].include?(uri.host) && ENV.key?('APPRAISAL_INITIALIZED') }
)

Dir['test/support/*.rb'].each { |f| load(f) }

if ENV['CI']
  Minitest::Reporters.use!([
                             Minitest::Reporters::JUnitReporter.new('_junit', false),
                             Minitest::Reporters::SpecReporter.new
                           ])
else
  Minitest::Reporters.use!([
                             Minitest::Reporters::SpecReporter.new
                           ])
end
Minitest::Test.include(Instana::TestHelpers)
