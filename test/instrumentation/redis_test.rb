# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'

class RedisTest < Minitest::Test
  def setup
    ::Instana.config[:redis] = { :enabled => true }
    if ENV.key?('REDIS_URL')
      @redis_url = ENV['REDIS_URL']
    else
      @redis_url = "redis://localhost:6379"
    end
    @redis_client = Redis.new(url: @redis_url)
  end

  def test_normal_call
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    assert_redis_trace('SET')
  end

  def test_normal_call_as_root_exit_span
    clear_all!

    ::Instana.config[:allow_exit_as_root] = true

    @redis_client.set('hello', 'world')

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    redis_span = spans[0]

    # first_span is the parent of second_span
    assert_equal :redis, redis_span[:n]

    data = redis_span[:data]

    uri = URI.parse(@redis_url)
    assert_equal "#{uri.host}:#{uri.port}", data[:redis][:connection]

    assert_equal "0", data[:redis][:db]
    assert_equal "SET", data[:redis][:command]
  end

  def test_georadius
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      @redis_client.georadius('Sicily', '15', '37', '200', 'km', 'WITHCOORD', 'WITHDIST')
    end

    assert_redis_trace('GEORADIUS')
  end

  def test_normal_call_with_error
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      begin
        @redis_client.zadd('hello', 'invalid', 'value')
      rescue
      end
    end

    assert_redis_trace('ZADD', with_error: 'ERR value is not a valid float')
  end

  def test_pipeline_call
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      @redis_client.pipelined do |pipeline|
        pipeline.set('hello', 'world')
        pipeline.set('other', 'world')
      end
    end

    assert_redis_trace('PIPELINE')
  end

  def test_pipeline_call_with_error
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      begin
        @redis_client.pipelined do |pipeline|
          pipeline.set('other', 'world')
          pipeline.call('invalid')
        end
      rescue
      end
    end

    assert_redis_trace('PIPELINE', with_error: "ERR unknown command 'invalid'")
  end

  def test_multi_call
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      @redis_client.multi do |multi|
        multi.set('hello', 'world')
        multi.set('other', 'world')
      end
    end

    assert_redis_trace('MULTI')
  end

  def test_multi_call_with_error
    clear_all!

    Instana.tracer.in_span(:redis_test) do
      begin
        @redis_client.multi do |multi|
          multi.set('other', 'world')
          multi.call('invalid')
        end
      rescue
      end
    end

    assert_redis_trace('MULTI', with_error: "ERR unknown command 'invalid'")
  end

  private

  def assert_redis_trace(command, with_error: nil)
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    first_span, second_span = spans.to_a.reverse

    # first_span is the parent of second_span
    assert_equal first_span[:s], second_span[:p]
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]

    data = second_span[:data]

    uri = URI.parse(@redis_url)
    assert_equal "#{uri.host}:#{uri.port}", data[:redis][:connection]

    assert_equal "0", data[:redis][:db]
    assert_equal command, data[:redis][:command]

    if with_error
      assert_equal true, data[:redis][:error]
      assert data[:log].key?(:message)
    end
  end
end

class RedisSpanFilteringTest < Minitest::Test
  def setup
    if ENV.key?('REDIS_URL')
      @redis_url = ENV['REDIS_URL']
    else
      @redis_url = "redis://localhost:6379"
    end
    @redis_client = Redis.new(url: @redis_url)

    # Reset span filtering configuration before each test
    ::Instana::SpanFiltering.reset
    ::Instana::SpanFiltering.initialize

    clear_all!
  end

  def teardown
    # Reset span filtering configuration after each test
    ::Instana::SpanFiltering.reset
    ::Instana::SpanFiltering.initialize
  end

  def test_redis_exclude_rule_filters_spans
    # Configure span filtering to exclude Redis SET operations
    condition1 = ::Instana::SpanFiltering::Condition.new('type', 'redis')
    condition2 = ::Instana::SpanFiltering::Condition.new('redis.command', 'SET')
    rule = ::Instana::SpanFiltering::FilterRule.new('Exclude Redis SET', false, [condition1, condition2])
    ::Instana::SpanFiltering.configuration.exclude_rules << rule

    # Execute Redis SET operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is filtered out)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  end

  def test_redis_include_rule_keeps_only_matching_spans
    # Configure span filtering to only include Redis GET operations
    condition1 = ::Instana::SpanFiltering::Condition.new('type', 'redis')
    condition2 = ::Instana::SpanFiltering::Condition.new('redis.command', 'GET')
    condition3 = ::Instana::SpanFiltering::Condition.new('type', 'sdk')

    rule1 = ::Instana::SpanFiltering::FilterRule.new('Include Redis GET', false, [condition1, condition2])
    rule2 = ::Instana::SpanFiltering::FilterRule.new('Include all SDK Spans GET', false, [condition3])
    ::Instana::SpanFiltering.configuration.include_rules << rule1 << rule2
    # Execute Redis SET operation (should be filtered out)

    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end
    # Verify that only the parent span is reported (Redis SET span is filtered out)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]

    clear_all!

    # Execute Redis GET operation (should be included)
    Instana.tracer.in_span(:redis_test) do
      @redis_client.get('hello')
    end

    # Verify that both spans are reported
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    first_span, second_span = spans.to_a.reverse
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]
    assert_equal "GET", second_span[:data][:redis][:command]
  end

  def test_redis_filtering_deactivated
    # Configure span filtering but deactivate it
    condition1 = ::Instana::SpanFiltering::Condition.new('type', 'redis')
    condition2 = ::Instana::SpanFiltering::Condition.new('redis.command', 'SET')
    rule = ::Instana::SpanFiltering::FilterRule.new('Exclude Redis SET', false, [condition1, condition2])
    ::Instana::SpanFiltering.configuration.exclude_rules << rule
    ::Instana::SpanFiltering.configuration.instance_variable_set(:@deactivated, true)

    # Execute Redis SET operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that both spans are reported (filtering is deactivated)
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    first_span, second_span = spans.to_a.reverse
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]
  end

  def test_redis_command_pattern_matching
    # Configure span filtering to exclude Redis commands that start with 'S'
    condition1 = ::Instana::SpanFiltering::Condition.new('type', 'redis')
    condition2 = ::Instana::SpanFiltering::Condition.new('redis.command', 'S', 'startswith')
    rule = ::Instana::SpanFiltering::FilterRule.new('Exclude Redis S* commands', false, [condition1, condition2])
    ::Instana::SpanFiltering.configuration.exclude_rules << rule

    # Execute Redis SET operation (should be filtered out)
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]

    clear_all!

    # Execute Redis GET operation (should not be filtered out)
    Instana.tracer.in_span(:redis_test) do
      @redis_client.get('hello')
    end

    # Verify that both spans are reported
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    first_span, second_span = spans.to_a.reverse
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]
    assert_equal "GET", second_span[:data][:redis][:command]
  end

  private

  def clear_all!
    ::Instana.processor.clear!
    ::Instana.tracer.clear!
  end
end
