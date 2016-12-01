$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
ENV['INSTANA_GEM_TEST'] = 'true'
require "rubygems"
require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']
require 'webmock/minitest'

# Boot background webservers to test against.
require "./test/servers/rackapp_6511"

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

Bundler.require(:default, :test)
