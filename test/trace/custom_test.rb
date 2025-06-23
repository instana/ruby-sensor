# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

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

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans.first
    assert_equal :sdk, first_span[:n]

    assert first_span[:ts].is_a?(Integer)
    assert (first_span[:ts]).positive?
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)

    assert first_span.key?(:data)
    assert first_span[:data].key?(:sdk)
    assert first_span[:data][:sdk].key?(:custom)
    assert first_span[:data][:sdk][:custom].key?(:tags)
    assert_equal :custom_trace, first_span[:data][:sdk][:name]
    assert_equal 1, first_span[:data][:sdk][:custom][:tags][:one]

    # Custom tracing root spans should default to entry type
    assert_equal 1, first_span[:k]
    assert_equal :entry, first_span[:data][:sdk][:type]

    assert first_span.key?(:f)
    assert_equal ::Instana.agent.source, first_span[:f]
  end

  # automagic (TM) as seen in the docs:
  # https://www.ibm.com/docs/en/instana-observability/current?topic=ruby-tracing-sdk#the-instana-ruby-tracing-sdk
  def test_custom_tracing_with_nested_automagic
    clear_all!
    assert_equal false, ::Instana.tracer.tracing?

    kvs = {}
    kvs[:on_entry_kv] = 1
    kvs[:arguments] = [[1, 2, 3], "test_arg", :ok]
    kvs[:return] = true

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, :on_trace_start => 1)
    assert_equal true, ::Instana.tracer.tracing?

    # Now the automagic
    ::Instana.tracer.trace(:custom_span, kvs) do
      answer = 42 * 1
      active_span = ::Instana.tracer.current_span
      active_span.set_tag(:answer, answer)

      # And now nested automagic
      ::Instana.tracer.trace(:custom_span2, kvs) do
        was_here = 'stan'
        active_span = ::Instana.tracer.current_span
        active_span.set_tag(:was_here, was_here)
      end
    end

    # End tracing
    ::Instana.tracer.log_end(:rack, {:on_trace_end => 1})
    assert_equal false, ::Instana.tracer.tracing?

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    second_span = find_first_span_by_name(spans, :custom_span)
    third_span = find_first_span_by_name(spans, :custom_span2)

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
    assert_equal 42, second_span[:data][:sdk][:custom][:tags][:answer]

    assert_equal :sdk, third_span[:n]
    assert third_span.key?(:data)
    assert third_span[:data].key?(:sdk)
    assert third_span[:data][:sdk].key?(:custom)
    assert third_span[:data][:sdk][:custom].key?(:tags)
    assert :custom_span, third_span[:data][:sdk][:name]
    assert :unknown, third_span[:data][:sdk][:type]
    assert [[1, 2, 3], "test_arg", :ok], third_span[:data][:sdk][:arguments]
    assert true, third_span[:data][:sdk][:return]
    assert_equal 1, third_span[:data][:sdk][:custom][:tags][:on_entry_kv]
    assert_equal 'stan', third_span[:data][:sdk][:custom][:tags][:was_here]
  end

  def test_custom_tracing_with_args
    clear_all!
    assert_equal false, ::Instana.tracer.tracing?

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, :on_trace_start => 1)
    assert_equal true, ::Instana.tracer.tracing?

    kvs = {}
    kvs[:on_entry_kv] = 1
    kvs[:arguments] = [[1, 2, 3], "test_arg", :ok]
    kvs[:return] = true

    ::Instana.tracer.log_entry(:custom_span, kvs)
    ::Instana.tracer.log_info({:on_info_kv => 1})
    ::Instana.tracer.log_exit(:custom_span, :on_exit_kv => 1)

    # End tracing
    ::Instana.tracer.log_end(:rack, {:on_trace_end => 1})
    assert_equal false, ::Instana.tracer.tracing?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = find_first_span_by_name(spans, :rack)
    second_span = find_first_span_by_name(spans, :custom_span)

    assert first_span[:ts].is_a?(Integer)
    assert (first_span[:ts]).positive?
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
      kvs[:arguments] = [[1, 2, 3], "test_arg", :ok]
      kvs[:return] = true

      ::Instana.tracer.log_entry(:custom_span, kvs)
      raise "custom tracing error.  This is only a test"
    rescue => e
      ::Instana.tracer.log_error(e)
    ensure
      ::Instana.tracer.log_exit(:custom_span, :on_exit_kv => 1)
    end
    ::Instana.tracer.log_end(:rack, {:on_trace_end => 1})
    assert_equal false, ::Instana.tracer.tracing?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = find_first_span_by_name(spans, :rack)
    second_span = find_first_span_by_name(spans, :custom_span)

    assert first_span[:ts].is_a?(Integer)
    assert (first_span[:ts]).positive?
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)

    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:on_trace_start)
    assert_equal 1, first_span[:data][:on_trace_start]
    assert first_span[:data].key?(:on_trace_end)
    assert_equal 1, first_span[:data][:on_trace_end]

    assert second_span[:ts].is_a?(Integer)
    assert (second_span[:ts]).positive?
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
