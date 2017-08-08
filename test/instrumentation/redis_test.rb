require 'test_helper'

class RedisTest < Minitest::Test
  def test_normal_call
    clear_all!

    Instana.tracer.start_or_continue_trace(:redis_test) do
      $redis.set('hello', 'world')
    end

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
    data = second_span[:data][:sdk][:custom][:redis]

    uri = URI.parse(ENV['I_REDIS_URL'])
    assert_equal uri.host, data[:host]
    assert_equal uri.port, data[:port]
    assert_equal 0, data[:db]
    assert_equal 'set', data[:operation]
    assert_equal 'set hello world', data[:command]
  end

  def test_normal_call_with_error
    clear_all!
  end

  def test_pipeline_call
    clear_all!
  end

  def test_multi_call
    clear_all!
  end
end
