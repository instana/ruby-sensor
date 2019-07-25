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

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length
    t = traces.first
    assert_equal 2, t.spans.size
    spans = t.spans.to_a
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

    traces = ::Instana.processor.queued_traces
    assert_equal 2, traces.length
    first_trace, second_trace = traces

    # Both traces should have the same ID
    assert first_trace.id == second_trace.id

    # Validate the first original thread span
    assert_equal 1, first_trace.spans.size
    spans = first_trace.spans.to_a
    first_span = spans[0]
    assert_equal :rack, first_span.name
    assert first_span.duration
    assert_equal 1, first_span[:data][:rack_start_kv]
    assert_equal 1, first_span[:data][:rack_end_kv]

    # Validate the second background thread trace
    assert_equal 2, second_trace.spans.size
    spans = second_trace.spans.to_a
    first_span, second_span = spans

    # first span in second trace
    assert_equal :async_thread, first_span.name
    assert first_span.duration
    assert_equal 1, first_span[:data][:sdk][:custom][:tags][:async_start]
    assert_equal 1, first_span[:data][:sdk][:custom][:tags][:async_end]

    # second span in second trace
    assert_equal :sleepy_time, second_span.name
    assert second_span.duration
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:tired]
    assert_equal 1, second_span[:data][:sdk][:custom][:tags][:wake_up]

    # Validate linkage
    # first_span is the parent of first_span
    assert_equal first_span[:s], second_span[:p]
    # same trace id
    assert_equal first_span[:t], second_span[:t]
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

    # Begin trace validation
    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length
    trace = traces.first
    assert_equal 4, trace.spans.size
    first_span, second_span, third_span, fourth_span = trace.spans.to_a

    assert trace.complete?

    # Linkage
    assert_equal first_span[:s], second_span[:p]
    assert_equal first_span[:s], third_span[:p]
    assert_equal first_span[:s], fourth_span[:p]

    # same trace id
    assert_equal first_span[:t], second_span[:t]
    assert_equal first_span[:t], third_span[:t]
    assert_equal first_span[:t], fourth_span[:t]

    assert !first_span.custom?
    assert second_span.custom?
    assert third_span.custom?
    assert fourth_span.custom?

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


  def test_staged_trace_moved_to_queue
    clear_all!

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:rack, {:rack_start_kv => 1})

    # Start an asynchronous span
    span = ::Instana.tracer.log_async_entry(:my_async_op, { :async_entry_kv => 1})

    refute_nil span
    refute_nil span.context

    # Current span should still be rack
    assert_equal :rack, ::Instana.tracer.current_trace.current_span_name

    # End tracing with a still outstanding async span (above)
    ::Instana.tracer.log_end(:rack, {:rack_end_kv => 1})

    # Make sure everything is settled
    sleep 0.2

    # Now end the async span completing the trace
    ::Instana.tracer.log_async_exit(:my_async_op, { :exit_kv => 1 }, span)
  end
end
