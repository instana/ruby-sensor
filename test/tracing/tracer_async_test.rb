require 'test_helper'

class TracerAsyncTest < Minitest::Test
  def test_same_thread_async_tracing
    clear_all!

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, {:rack_start_kv => 1})

    # Start an asynchronous span
    span = ::Instana.tracer.log_async_entry(:my_async_op, { :entry_kv => 1})

    refute_nil span
    refute_nil span.context

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # End an asynchronous span
    ::Instana.tracer.log_async_exit(:my_async_op, { :exit_kv => 1 }, span)

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # End tracing
    ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[0]
    second_span = spans[1]

    # Both spans have a duration
    assert first_span[:d]
    assert second_span[:d]

    # first_span is the parent of first_span
    assert_equal first_span[:s], second_span[:p]
    # same trace id
    assert_equal first_span[:t], second_span[:t]

    # KV checks
    assert_equal 1, first_span[:data][:rack_start_kv]
    assert_equal 1, first_span[:data][:rack_end_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:entry_kv]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:exit_kv]
  end

  def test_diff_thread_async_tracing
    clear_all!

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, {:rack_start_kv => 1})

    t_context = ::Instana.tracer.context
    refute_nil t_context.trace_id
    refute_nil t_context.span_id

    Thread.new do
      ::Instana.tracer.log_start_or_continue(:async_thread, { :async_start => 1 }, t_context.to_hash)
      ::Instana.tracer.log_entry(:sleepy_time, { :tired => 1 })
      # Sleep beyond the end of this root trace
      sleep 0.5
      ::Instana.tracer.log_exit(:sleepy_time, { :wake_up => 1})
      ::Instana.tracer.log_end(:async_thread, { :async_end => 1 })
    end

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # End tracing
    ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    assert_equal false, ::Instana.tracer.tracing?

    # Sleep for 1 seconds to wait for the async thread to finish
    sleep 1

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    first_span, second_span, third_span = spans

    # Validate the first original thread span
    assert_equal :rack, first_span[:n]
    assert first_span[:d]
    assert_equal 1, first_span[:data][:rack_start_kv]
    assert_equal 1, first_span[:data][:rack_end_kv]

    # first span in second trace
    assert_equal :sdk, second_span[:n]
    assert_equal :async_thread, second_span[:data][:sdk][:name]
    assert second_span[:d]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:async_start]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:async_end]

    # second span in second trace
    assert_equal :sdk, third_span[:n]
    assert_equal :sleepy_time, third_span[:data][:sdk][:name]
    assert third_span[:d]
    assert_equal 1, third_span[:data][:sdk][:custom][:tags][:tired]
    assert_equal 1, third_span[:data][:sdk][:custom][:tags][:wake_up]

    # Validate linkage
    # All spans have the same trace ID
    assert first_span[:t]==second_span[:t] && second_span[:t]==third_span[:t]

    assert_equal third_span[:p], second_span[:s]
    assert_equal second_span[:p], first_span[:s]

    assert first_span[:t]  == first_span[:s]
    assert second_span[:t] != second_span[:s]
    assert third_span[:t]  != third_span[:s]
  end

  def test_out_of_order_async_tracing
    clear_all!

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, {:rack_start_kv => 1})

    # Start three asynchronous spans
    span1 = ::Instana.tracer.log_async_entry(:my_async_op, { :entry_kv => 1})
    span2 = ::Instana.tracer.log_async_entry(:my_async_op, { :entry_kv => 2})
    span3 = ::Instana.tracer.log_async_entry(:my_async_op, { :entry_kv => 3})

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # Log info to the async spans (out of order)
    span2.set_tags({ :info_kv => 2 })
    span1.set_tags({ :info_kv => 1 })
    span3.set_tags({ :info_kv => 3 })

    # Log out of order errors to the async spans
    span3.add_error(Exception.new("Async span 3"))
    span2.add_error(Exception.new("Async span 3"))

    # End two out of order asynchronous spans
    span3.set_tags({ :exit_kv => 3 })
    span3.close
    span2.set_tags({ :exit_kv => 2 })
    span2.close

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # End tracing
    ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    # Log an error to and close out the remaining async span after the parent trace has finished
    span1.add_error(Exception.new("Async span 1"))
    span1.set_tags({ :exit_kv => 1 })
    span1.close

    spans = ::Instana.processor.queued_spans
    assert_equal 4, spans.length
    first_span, second_span, third_span, fourth_span = spans

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
end
