require 'test_helper'

class DalliTest < Minitest::Test
  def setup
    @memcached_host = ENV['MEMCACHED_HOST'] || '127.0.0.1:11211'
    @dc = Dalli::Client.new(@memcached_host)
  end

  def test_config_defaults
    assert ::Instana.config[:dalli].is_a?(Hash)
    assert ::Instana.config[:dalli].key?(:enabled)
    assert_equal true, ::Instana.config[:dalli][:enabled]
  end

  def test_basic_get
    clear_all!

    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      @dc.get(:instana)
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    # Excon validation
    assert_equal 2, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :dalli_test, first_span.name
    assert_equal :memcache, second_span.name
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :get, second_span[:data][:memcache][:command]
  end

  def test_basic_set
    clear_all!

    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      @dc.set(:instana, :rocks)
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count
    trace = traces.first

    # Excon validation
    assert_equal 2, trace.spans.count
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    assert_equal :dalli_test, first_span.name
    assert_equal :memcache, second_span.name
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :set, second_span[:data][:memcache][:command]
  end
end
