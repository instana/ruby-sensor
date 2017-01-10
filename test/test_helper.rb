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
::WebMock.disable_net_connect!(allow_localhost: true)

# Boot background webservers to test against.
require "./test/servers/rackapp_6511"

Minitest::Reporters.use! MiniTest::Reporters::SpecReporter.new

# Set this (or a subset) if you want increased debug output
#::Instana.logger.debug_level = [ :agent, :agent_comm, :trace ]

# Used to reset the gem to boot state.  It clears out any queued and/or staged
# traces and resets the tracer to no active trace.
#
def clear_all!
  ::Instana.processor.clear!
  ::Instana.tracer.clear!
  nil
end
