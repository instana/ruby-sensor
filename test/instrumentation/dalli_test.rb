# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'

class DalliTest < Minitest::Test
  def setup
    @memcached_host = ENV['MEMCACHED_HOST'] || '127.0.0.1:11211'
    @dc = Dalli::Client.new(@memcached_host, :namespace => "instana_test")
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def test_config_defaults
    assert ::Instana.config[:dalli].is_a?(Hash)
    assert ::Instana.config[:dalli].key?(:enabled)
    assert_equal true, ::Instana.config[:dalli][:enabled]
  end

  def test_basic_get
    clear_all!

    @dc.set(:instana, :boom)

    result = nil
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.get(:instana)
    end

    assert_equal :boom, result

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :get, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :instana, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_basic_get_as_root_exit_span
    clear_all!
    @dc.set(:instana, :boom)

    ::Instana.config[:allow_exit_as_root] = true
    result = @dc.get(:instana)

    assert_equal :boom, result

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans[0]

    assert_equal :memcache, first_span[:n]
    assert_equal false, first_span.key?(:error)
    assert_nil first_span[:p]
    assert first_span[:t] == first_span[:s]
    assert first_span[:data].key?(:memcache)
    assert first_span[:data][:memcache].key?(:command)
    assert_equal :get, first_span[:data][:memcache][:command]
    assert first_span[:data][:memcache].key?(:key)
    assert_equal :instana, first_span[:data][:memcache][:key]
    assert first_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', first_span[:data][:memcache][:namespace]
    assert first_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, first_span[:data][:memcache][:server]
  end

  def test_basic_set
    clear_all!

    result = nil
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.set(:instana, :rocks)
    end

    assert result.is_a?(Integer)

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :set, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :instana, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_replace
    clear_all!

    @dc.set(:instana, :rocks)
    result = nil
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.replace(:instana, :rocks)
    end

    assert result.is_a?(Integer)

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :replace, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :instana, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_delete
    clear_all!

    @dc.set(:instana, :rocks)
    result = nil
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.delete(:instana)
    end

    assert_equal true, result

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :delete, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :instana, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_incr
    clear_all!

    result = nil
    @dc.set(:counter, 0, nil, :raw => true)
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.incr(:counter, 1, nil, 0)
    end

    assert_equal 1, result

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :incr, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :counter, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_decr
    clear_all!

    result = nil
    @dc.set(:counter, 0, nil, :raw => true)
    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      result = @dc.decr(:counter, 1, nil, 0)
    end

    assert_equal 0, result

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :decr, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :counter, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
  end

  def test_get_multi
    clear_all!

    @dc.set(:one, 1)
    @dc.set(:three, 3)

    ::Instana.tracer.start_or_continue_trace(:dalli_test) do
      @dc.get_multi(:one, :two, :three, :four)
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal false, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :get_multi, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:keys)
    assert_equal "one, two, three, four", second_span[:data][:memcache][:keys]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:server)
    assert_equal @memcached_host, second_span[:data][:memcache][:server]
    assert second_span[:data][:memcache].key?(:hits)
    assert_equal 2, second_span[:data][:memcache][:hits]
  end

  def test_get_error_logging
    clear_all!

    # Invalid/broken client not connected to a server
    broken_dc = Dalli::Client.new('128.0.0.100:11222', :namespace => "instana_test", :expires_in => 1)

    result = nil
    begin
      ::Instana.tracer.start_or_continue_trace(:dalli_test) do
        result = broken_dc.get(:instana)
      end
    rescue
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    validate_sdk_span(first_span, {:name => :dalli_test, :type => :entry})

    assert_equal :memcache, second_span[:n]
    assert_equal true, second_span.key?(:error)
    assert second_span[:p] == first_span[:s]
    assert first_span[:t] == first_span[:s]
    assert second_span[:data].key?(:memcache)
    assert second_span[:data][:memcache].key?(:command)
    assert_equal :get, second_span[:data][:memcache][:command]
    assert second_span[:data][:memcache].key?(:key)
    assert_equal :instana, second_span[:data][:memcache][:key]
    assert second_span[:data][:memcache].key?(:namespace)
    assert_equal 'instana_test', second_span[:data][:memcache][:namespace]
    assert second_span[:data][:memcache].key?(:error)
  end
end
