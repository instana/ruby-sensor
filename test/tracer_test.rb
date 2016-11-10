require 'test_helper'

class TracerTest < Minitest::Test
  def test_that_it_has_a_valid_tracer
    refute_nil ::Instana.tracer
    assert ::Instana.tracer.is_a?(::Instana::Tracer)
  end

  def test_basic_trace_block
    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      sleep 0.5
    end
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 1, t.spans.size
    assert t.valid?
  end

  def test_complex_trace_block
    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      sleep 0.2
      ::Instana.tracer.trace(:sub_block, {:sub_two => 2}) do
        sleep 0.2
      end
    end
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 2, t.spans.size
    assert t.valid?
  end

  def test_basic_low_level_tracing
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    ::Instana.tracer.log_info({:info_logged => 1})
    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 1, t.spans.size
    assert t.valid?
  end

  def test_complex_low_level_tracing
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    ::Instana.tracer.log_info({:info_logged => 1})

    ::Instana.tracer.log_entry(:sub_task)
    ::Instana.tracer.log_info({:sub_task_info => 1})
    ::Instana.tracer.log_exit(:sub_task, {:sub_task_exit_info => 1})

    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 2, t.spans.size
    assert t.valid?
  end

  def test_block_tracing_error_capture
    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      raise Exception.new("Block exception test error")
    end
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 1, t.spans.size
    assert t.valid?
    assert t.has_error?
  end

  def test_low_level_error_logging
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    ::Instana.tracer.log_info({:info_logged => 1})
    ::Instana.tracer.log_error(Exception.new("Low level tracing api error"))
    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})
    t = ::Instana.tracer.instance_variable_get(:@trace)
    assert_equal 1, t.spans.size
    assert t.valid?
    assert t.has_error?
  end
end
