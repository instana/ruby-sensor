require 'test_helper'

class CustomTracingTest < Minitest::Test
  def test_custom_tracing
    clear_all!

    assert_equal false, ::Instana.tracer.tracing?
    # Start tracing
    ::Instana.tracer.log_start_or_continue(:custom_trace, {:one => 1})
    assert_equal true, ::Instana.tracer.tracing?
    ::Instana.tracer.log_info({:info_logged => 1})
    # End tracing
    ::Instana.tracer.log_end(:custom_trace, {:close_one => 1})
    assert_equal false, ::Instana.tracer.tracing?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length
    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?

    first_span = t.spans.first
    assert_equal :sdk, first_span[:n]

    assert first_span[:ts].is_a?(Integer)
    assert first_span[:ts] > 0
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)

    assert first_span.key?(:data)
    assert first_span[:data].key?(:sdk)
    assert first_span[:data][:sdk].key?(:custom)
    assert first_span[:data][:sdk][:custom].key?(:tags)
    assert_equal :custom_trace, first_span[:data][:sdk][:name]
    assert_equal 1, first_span[:data][:sdk][:custom][:tags][:one]
    assert_equal :ruby, first_span[:ta]

    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_custom_tracing_with_args
    clear_all!
    assert_equal false, ::Instana.tracer.tracing?

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, :on_trace_start => 1)
    assert_equal true, ::Instana.tracer.tracing?

    kvs = {}
    kvs[:on_entry_kv] = 1
    kvs[:arguments] = [[1,2,3], "test_arg", :ok]
    kvs[:return] = true

    ::Instana.tracer.log_entry(:custom_span, kvs)
    ::Instana.tracer.log_info({:on_info_kv => 1})
    ::Instana.tracer.log_exit(:custom_span, :on_exit_kv => 1)

    # End tracing
    ::Instana.tracer.log_end(:rack, {:on_trace_end => 1})
    assert_equal false, ::Instana.tracer.tracing?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length
    t = traces.first
    assert_equal 2, t.spans.size
    assert t.valid?

    first_span, second_span = t.spans.to_a

    assert first_span[:ts].is_a?(Integer)
    assert first_span[:ts] > 0
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)

    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:on_trace_start)
    assert_equal 1, first_span[:data][:on_trace_start]
    assert first_span[:data].key?(:on_trace_end)
    assert_equal 1, first_span[:data][:on_trace_end]

    assert_equal :sdk, second_span[:n]
    assert second_span.key?(:data)
    assert second_span[:data].key?(:sdk)
    assert second_span[:data][:sdk].key?(:custom)
    assert second_span[:data][:sdk][:custom].key?(:tags)
    assert :custom_span, second_span[:data][:sdk][:name]
    assert :unknown, second_span[:data][:sdk][:type]
    assert [[1, 2, 3], "test_arg", :ok], second_span[:data][:sdk][:arguments]
    assert true, second_span[:data][:sdk][:return]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:on_entry_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:on_info_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:on_exit_kv]
  end

  def test_custom_tracing_with_error
    clear_all!
    assert_equal false, ::Instana.tracer.tracing?

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, :on_trace_start => 1)
    assert_equal true, ::Instana.tracer.tracing?

    begin
      kvs = {}
      kvs[:on_entry_kv] = 1
      kvs[:arguments] = [[1,2,3], "test_arg", :ok]
      kvs[:return] = true

      ::Instana.tracer.log_entry(:custom_span, kvs)
      raise "custom tracing error.  This is only a test"
      ::Instana.tracer.log_info({:on_info_kv => 1})
    rescue => e
      ::Instana.tracer.log_error(e)
    ensure
      ::Instana.tracer.log_exit(:custom_span, :on_exit_kv => 1)
    end
    ::Instana.tracer.log_end(:rack, {:on_trace_end => 1})
    assert_equal false, ::Instana.tracer.tracing?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length
    t = traces.first
    assert_equal 2, t.spans.size
    assert t.valid?

    first_span, second_span = t.spans.to_a

    assert first_span[:ts].is_a?(Integer)
    assert first_span[:ts] > 0
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)

    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:on_trace_start)
    assert_equal 1, first_span[:data][:on_trace_start]
    assert first_span[:data].key?(:on_trace_end)
    assert_equal 1, first_span[:data][:on_trace_end]

    assert second_span[:ts].is_a?(Integer)
    assert second_span[:ts] > 0
    assert second_span[:d].is_a?(Integer)
    assert second_span[:d].between?(0, 5)

    assert_equal :sdk, second_span[:n]
    assert second_span.key?(:data)
    assert second_span[:data].key?(:sdk)
    assert second_span[:data][:sdk].key?(:custom)
    assert second_span[:data][:sdk][:custom].key?(:tags)
    assert :custom_span, second_span[:data][:sdk][:name]
    assert :unknown, second_span[:data][:sdk][:type]
    assert [[1, 2, 3], "test_arg", :ok], second_span[:data][:sdk][:arguments]
    assert true, second_span[:data][:sdk][:return]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:on_entry_kv]
    assert !second_span[:data][:sdk][:custom][:tags].key?(:on_info_kv)
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:on_exit_kv]

    # Check the error
    assert_equal true, second_span[:error]
    assert_equal 1, second_span[:ec]
  end
end
