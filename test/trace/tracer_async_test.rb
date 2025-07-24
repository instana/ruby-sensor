# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'

class TracerAsyncTest < Minitest::Test
  def test_same_thread_async_tracing
    clear_all!

    # Start tracing
    ::Instana.tracer.start_span(:rack, attributes: {:rack_start_kv => 1})

    # Start an asynchronous span
    span = ::Instana.tracer.log_async_entry(:my_async_op, { :entry_kv => 1})

    refute_nil span
    refute_nil span.context

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_span.name

    # End an asynchronous span
    ::Instana.tracer.log_async_exit(:my_async_op, { :exit_kv => 1 }, span)

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_span.name

    # End tracing
    ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    async_span = find_first_span_by_name(spans, :my_async_op)

    # Both spans have a duration
    assert rack_span[:d]
    assert async_span[:d]

    # first_span is the parent of first_span
    assert_equal rack_span[:s], async_span[:p]
    # same trace id
    assert_equal rack_span[:t], async_span[:t]

    # KV checks
    assert_equal 1, rack_span[:data][:rack_start_kv]
    assert_equal 1, rack_span[:data][:rack_end_kv]
    assert_equal 1, async_span[:data][:sdk][:custom][:tags][:entry_kv]
    assert_equal 1, async_span[:data][:sdk][:custom][:tags][:exit_kv]
  end

  def test_diff_thread_async_tracing
    clear_all!

    # Start tracing
    span = ::Instana.tracer.start_span(:rack, attributes: {:rack_start_kv => 1})

    t_context = ::Instana.tracer.context
    refute_nil t_context.trace_id
    refute_nil t_context.span_id

    Thread.new do
      span1 = ::Instana::Trace.with_span(OpenTelemetry::Trace.non_recording_span(t_context)) do
        ::Instana.tracer.start_span(:async_thread, attributes: { :async_start => 1 })
      end
      span2 = ::Instana::Trace.with_span(span1) do
        ::Instana.tracer.start_span(:sleepy_time, attributes: { :tired => 1 })
      end

      # Sleep beyond the end of this root trace
      sleep 0.5
      span2.set_tags({ :wake_up => 1})
      span2.finish
      span1.set_tags({:async_end => 1})
      span1.finish
    end
    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_span.name
    span.set_tags({:rack_end_kv => 1})
    span.finish
    # End tracing
    # ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    assert_equal false, ::Instana.tracer.tracing?

    # Sleep for 1 seconds to wait for the async thread to finish
    sleep 1

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    async_span1 = find_first_span_by_name(spans, :async_thread)
    async_span2 = find_first_span_by_name(spans, :sleepy_time)

    # Validate the first original thread span
    assert_equal :rack, rack_span[:n]
    assert rack_span[:d]
    assert_equal 1, rack_span[:data][:rack_start_kv]
    assert_equal 1, rack_span[:data][:rack_end_kv]

    # first span in second trace
    assert_equal :sdk, async_span1[:n]
    assert_equal :async_thread, async_span1[:data][:sdk][:name]
    assert async_span1[:d]
    assert_equal 1, async_span1[:data][:sdk][:custom][:tags][:async_start]
    assert_equal 1, async_span1[:data][:sdk][:custom][:tags][:async_end]

    # second span in second trace
    assert_equal :sdk, async_span2[:n]
    assert_equal :sleepy_time, async_span2[:data][:sdk][:name]
    assert async_span2[:d]
    assert_equal 1, async_span2[:data][:sdk][:custom][:tags][:tired]
    assert_equal 1, async_span2[:data][:sdk][:custom][:tags][:wake_up]
    # Validate linkage
    # All spans have the same trace ID
    assert rack_span[:t] == async_span1[:t] && async_span1[:t] == async_span2[:t]

    assert_equal async_span2[:p], async_span1[:s]
    assert_equal async_span1[:p], rack_span[:s]

    assert rack_span[:t] == rack_span[:s]
    assert async_span1[:t] != async_span1[:s]
    assert async_span2[:t] != async_span2[:s]
  end

  def test_out_of_order_async_tracing
    clear_all!

    # Start tracing
    span = ::Instana.tracer.start_span(:rack, attributes: {:rack_start_kv => 1})

    # Start three asynchronous spans
    span1, span2, span3 = ::Instana::Trace.with_span(span) do
      span1 = ::Instana.tracer.start_span(:my_async_op1, attributes: { :entry_kv => 1})
      span2 = ::Instana.tracer.start_span(:my_async_op2, attributes: { :entry_kv => 2})
      span3 = ::Instana.tracer.start_span(:my_async_op3, attributes: { :entry_kv => 3})
      return span1, span2, span3
    end

    # Context awareness when using Opentelemetry is done through Opentelemetry::Context so the below test is invalid
    # Current span should still be rack
    # assert_equal :rack, ::Instana.tracer.current_span.name

    # Log info to the async spans (out of order)
    span2.set_tags({ :info_kv => 2 })
    span1.set_tags({ :info_kv => 1 })
    span3.set_tags({ :info_kv => 3 })

    # Log out of order errors to the async spans
    span3.record_exception(Exception.new("Async span 3"))
    span2.record_exception(Exception.new("Async span 3"))

    # End two out of order asynchronous spans
    span3.set_tags({ :exit_kv => 3 })
    span3.close
    span2.set_tags({ :exit_kv => 2 })
    span2.close

    # Context awareness when using Opentelemetry is done through Opentelemetry::Context so the below test is invalid
    # Current span should still be rack
    # assert_equal :rack, ::Instana.tracer.current_span.name

    # End tracing
    span.set_tags({:rack_end_kv => 1})
    span.finish

    # Log an error to and close out the remaining async span after the parent trace has finished
    span1.record_exception(Exception.new("Async span 1"))
    span1.set_tags({ :exit_kv => 1 })
    span1.close

    spans = ::Instana.processor.queued_spans
    assert_equal 4, spans.length

    first_span  = find_first_span_by_name(spans, :rack)
    second_span = find_first_span_by_name(spans, :my_async_op1)
    third_span  = find_first_span_by_name(spans, :my_async_op2)
    fourth_span = find_first_span_by_name(spans, :my_async_op3)

    # Assure all spans have completed
    assert first_span.key?(:d)
    assert second_span.key?(:d)
    assert third_span.key?(:d)
    assert fourth_span.key?(:d)

    # Linkage
    assert_equal first_span[:s], second_span[:p]
    assert_equal first_span[:s], third_span[:p]
    assert_equal first_span[:s], fourth_span[:p]

    # same trace id
    assert_equal first_span[:t], second_span[:t]
    assert_equal first_span[:t], third_span[:t]
    assert_equal first_span[:t], fourth_span[:t]

    assert first_span[:n]  != :sdk
    assert second_span[:n] == :sdk
    assert third_span[:n]  == :sdk
    assert fourth_span[:n] == :sdk

    # KV checks
    assert_equal 1, first_span[:data][:rack_start_kv]
    assert_equal 1, first_span[:data][:rack_end_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:entry_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:exit_kv]
    assert_equal 2, third_span[:data][:sdk][:custom][:tags][:entry_kv]
    assert_equal 2, third_span[:data][:sdk][:custom][:tags][:exit_kv]
    assert_equal 3, fourth_span[:data][:sdk][:custom][:tags][:entry_kv]
    assert_equal 3, fourth_span[:data][:sdk][:custom][:tags][:exit_kv]
  end

  def test_async_helpers
    clear_all!
    ::Instana.tracer.start_span(:rack)

    span1 = ::Instana.tracer.start_span(:async, attributes: {})
    span1.set_tags({a: 1})
    span1.record_exception(StandardError.new('Error'))
    span1.finish

    spans = ::Instana.processor.queued_spans
    span, = spans

    assert_equal({a: 1}, span[:data][:sdk][:custom][:tags])
    assert_equal(1, span[:ec])
  end

  def test_async_helpers_tag_exit
    clear_all!
    ::Instana.tracer.start_span(:rack)

    span1 = ::Instana.tracer.start_span(:async, attributes: {})
    span1.set_tags({a: 1})
    span1.finish

    spans = ::Instana.processor.queued_spans
    span, = spans

    assert_equal({a: 1}, span[:data][:sdk][:custom][:tags])
  end
end
