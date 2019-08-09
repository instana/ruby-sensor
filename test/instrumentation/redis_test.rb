require 'test_helper'

class RedisTest < Minitest::Test
  def test_normal_call
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      redis_client.set('hello', 'world')
    end
    redis_client.disconnect!

    assert_redis_trace('SET')
  end

  def test_normal_call_with_error
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        redis_client.zadd('hello', 'invalid', 'value')
      rescue; end
    end
    redis_client.disconnect!

    assert_redis_trace('ZADD', with_error: 'ERR value is not a valid float')
  end

  def test_pipeline_call
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      redis_client.pipelined do
        redis_client.set('hello', 'world')
        redis_client.set('other', 'world')
      end
    end

    assert_redis_trace('PIPELINE')
  end

  def test_pipeline_call_with_error
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        redis_client.pipelined do
          redis_client.set('other', 'world')
          redis_client.call('invalid')
        end
      rescue; end
    end

    assert_redis_trace('PIPELINE', with_error: "ERR unknown command 'invalid'")
  end

  def test_multi_call
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      redis_client.multi do
        redis_client.set('hello', 'world')
        redis_client.set('other', 'world')
      end
    end

    assert_redis_trace('MULTI')
  end

  def test_multi_call_with_error
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        redis_client.multi do
          redis_client.set('other', 'world')
          redis_client.call('invalid')
        end
      rescue; end
    end

    assert_redis_trace('MULTI', with_error: "ERR unknown command 'invalid'")
  end

  private

  def create_redis_client
    Redis.new(url: ENV['I_REDIS_URL'])
  end

  def assert_redis_trace(command, with_error: nil)
    assert_equal 1, ::Instana.processor.queue_count
    trace = ::Instana.processor.queued_traces.first

    assert_equal 2, trace.spans.count
    first_span, second_span = trace.spans.to_a

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]

    data = second_span[:data]

    uri = URI.parse(ENV['I_REDIS_URL'])
    assert_equal "#{uri.host}:#{uri.port}", data[:redis][:connection]

    assert_equal 0, data[:redis][:db]
    assert_equal command, data[:redis][:command]

    if with_error
      assert_equal true, data[:redis][:error]
      assert data[:log][:message].include?(with_error)
    end
  end
end
