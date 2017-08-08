require 'test_helper'

class RedisTest < Minitest::Test
  def test_normal_call
    clear_all!
    redis_client = create_redis_client

    Instana.tracer.start_or_continue_trace(:redis_test) do
      redis_client.set('hello', 'world')
    end
    redis_client.disconnect!

    assert_trace_for_normal_call
  end

  def test_normal_call_with_error
    clear_all!
    redis_client = create_redis_client

    redis_client.client.instance_eval do
      def read
        raise 'Something went wrong'
      end
    end

    Instana.tracer.start_or_continue_trace(:redis_test) do
      begin
        redis_client.set('hello', 'world')
      rescue; end
    end
    redis_client.disconnect!

    assert_trace_for_normal_call(with_error: 'Something went wrong')
  end

  def test_pipeline_call
    clear_all!
  end

  def test_multi_call
    clear_all!
  end

  private

  def create_redis_client
    Redis.new(url: ENV['I_REDIS_URL'])
  end

  def assert_trace_for_normal_call(with_error: nil)
    assert_equal 1, ::Instana.processor.queue_count
    trace = ::Instana.processor.queued_traces.first

    assert_equal 2, trace.spans.count
    first_span, second_span = trace.spans.to_a

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :sdk, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    assert_equal :redis, second_span[:data][:sdk][:name]
    data = second_span[:data][:sdk][:custom]

    uri = URI.parse(ENV['I_REDIS_URL'])
    assert_equal uri.host, data[:redis][:host]
    assert_equal uri.port, data[:redis][:port]
    assert_equal 0, data[:redis][:db]
    assert_equal 'set', data[:redis][:operation]
    assert_equal 'set hello world', data[:redis][:command]

    if with_error
      assert_equal true, data[:redis][:error]
      assert_equal with_error, data[:log][:message]
    end
  end
end
