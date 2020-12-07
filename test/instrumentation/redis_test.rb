require 'test_helper'

class RedisTest < Minitest::Test
  def setup
    if ENV.key?('REDIS_URL')
      @redis_url = ENV['REDIS_URL']
    else
      @redis_url = "redis://localhost:6379"
    end
    @redis_client = Redis.new(url: @redis_url)
  end

  def test_normal_call
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    assert_redis_trace('SET')
  end

  def test_georadius
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      @redis_client.georadius('Sicily', '15', '37', '200', 'km', 'WITHCOORD', 'WITHDIST')
    end

    assert_redis_trace('GEORADIUS')
  end

  def test_normal_call_with_error
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        @redis_client.zadd('hello', 'invalid', 'value')
      rescue; end
    end

    assert_redis_trace('ZADD', with_error: 'ERR value is not a valid float')
  end

  def test_pipeline_call
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      @redis_client.pipelined do
        @redis_client.set('hello', 'world')
        @redis_client.set('other', 'world')
      end
    end

    assert_redis_trace('PIPELINE')
  end

  def test_pipeline_call_with_error
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        @redis_client.pipelined do
          @redis_client.set('other', 'world')
          @redis_client.call('invalid')
        end
      rescue; end
    end

    assert_redis_trace('PIPELINE', with_error: "ERR unknown command 'invalid'")
  end

  def test_multi_call
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      @redis_client.multi do
        @redis_client.set('hello', 'world')
        @redis_client.set('other', 'world')
      end
    end

    assert_redis_trace('MULTI')
  end

  def test_multi_call_with_error
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        @redis_client.multi do
          @redis_client.set('other', 'world')
          @redis_client.call('invalid')
        end
      rescue; end
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
