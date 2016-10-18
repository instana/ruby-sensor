$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'instana'

require 'rubygems'
require 'bundler/setup'
require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

Bundler.require(:default, :test)
