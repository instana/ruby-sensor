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
when /rails/
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

# Used to reset the gem to boot state.  It clears out any queued and/or staged
# traces and resets the tracer to no active trace.
#
def clear_all!
  ::Instana.processor.clear!
  ::Instana.tracer.clear!
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

def validate_sdk_span(json_span, sdk_hash = {}, errored = false, ec = 1)
  assert_equal :sdk, json_span[:n]
  assert json_span.key?(:k)
  assert json_span.key?(:d)
  assert json_span.key?(:ts)

  for k,v in sdk_hash
    assert_equal v, json_span[:data][:sdk][k]
  end

  if errored
    assert_equal true, json_span[:error]
    assert_equal 1, json_span[:ec]
  end
end

def find_spans_by_name(spans, name)
  result = []
  for span in spans
    if span[:n] == :sdk
      if span[:data][:sdk][:name] == name
        result << span
      end
    elsif span[:n] == name
      result << span
    end
  end
  if result.empty?
    raise Exception.new("No SDK spans (#{name}) could be found")
  else
    return result
  end
end

def find_first_span_by_name(spans, name)
  for span in spans
    if span[:n] == :sdk
      if span[:data][:sdk][:name] == name
        return span
      end
    else
      if span[:n] == name
        return span
      end
    end
  end
  raise Exception.new("Span (#{name}) not found")
end

def find_span_by_id(spans, id)
  for span in spans
    if span[:s] == id
      return span
    end
  end
  raise Exception.new("Span with id (#{id}) not found")
end

# Finds the first span in +spans+ for which +block+ returns true
#
#     ar_span = find_first_span_by_qualifier(ar_spans) do |span|
#       span[:data][:activerecord][:sql] == sql
#     end
#
# This helper will raise an exception if no span evaluates to true against he provided block.
#
# +spans+: +Array+ of spans to search
# +block+: The Ruby block to evaluate against each span
def find_first_span_by_qualifier(spans, &block)
  spans.each do |span|
    if block.call(span)
      return span
    end
  end
  raise Exception.new("Span with qualifier not found")
end