$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
ENV['INSTANA_GEM_TEST'] = 'true'
require 'instana'

require 'rubygems'
require 'bundler/setup'
require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']
require 'webmock/minitest'

# Boot a background thread Rack app that we can throw requests at
require "./test/servers/rackapp_6511"

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

Bundler.require(:default, :test)
