require 'test_helper'

class TracerTest < Minitest::Test
  def test_that_it_has_a_valid_tracer
    refute_nil ::Instana.tracer
    assert ::Instana.tracer.is_a?(::Instana::Tracer)
  end

  def test_basic_trace_block
    ::Instana.processor.clear!

    assert_equal false, ::Instana.tracer.tracing?

    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      assert_equal true, ::Instana.tracer.tracing?
      sleep 0.5
    end

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count
    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?

    first_span = t.spans.first
    assert_equal :test_trace, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_errors_are_properly_propogated
    ::Instana.processor.clear!
    exception_raised = false
    begin
      ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
        raise Exception.new('Error in block - this should continue to propogate outside of tracing')
      end
    rescue Exception
      exception_raised = true
    end

    assert exception_raised

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count
    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?

    first_span = t.spans.first
    assert_equal :test_trace, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
    assert t.has_error?
  end

  def test_complex_trace_block
    ::Instana.processor.clear!
    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      sleep 0.2
      ::Instana.tracer.trace(:sub_block, {:sub_two => 2}) do
        sleep 0.2
      end
    end

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count
    t = traces.first
    assert_equal 2, t.spans.size
    assert t.valid?
  end

  def test_basic_low_level_tracing
    ::Instana.processor.clear!

    assert_equal false, ::Instana.tracer.tracing?
    # Start tracing
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    assert_equal true, ::Instana.tracer.tracing?
    ::Instana.tracer.log_info({:info_logged => 1})
    # End tracing
    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})
    assert_equal false, ::Instana.tracer.tracing?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count
    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?
  end

  def test_complex_low_level_tracing
    ::Instana.processor.clear!

    assert_equal false, ::Instana.tracer.tracing?

    # Start tracing
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    assert_equal true, ::Instana.tracer.tracing?
    ::Instana.tracer.log_info({:info_logged => 1})

    # Start tracing a sub span
    ::Instana.tracer.log_entry(:sub_task)
    assert_equal true, ::Instana.tracer.tracing?
    ::Instana.tracer.log_info({:sub_task_info => 1})
    # Exit from the sub span
    ::Instana.tracer.log_exit(:sub_task, {:sub_task_exit_info => 1})
    assert_equal true, ::Instana.tracer.tracing?

    # End tracing
    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})
    assert_equal false, ::Instana.tracer.tracing?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count

    t = traces.first
    assert_equal 2, t.spans.size
    assert t.valid?

    first_span = t.spans.first
    assert_equal :test_trace, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_block_tracing_error_capture
    ::Instana.processor.clear!
    exception_raised = false
    begin
      ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
        raise Exception.new("Block exception test error")
      end
    rescue Exception
      exception_raised = true
    end

    assert exception_raised

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count

    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?
    assert t.has_error?
  end

  def test_low_level_error_logging
    ::Instana.processor.clear!
    ::Instana.tracer.log_start_or_continue(:test_trace, {:one => 1})
    ::Instana.tracer.log_info({:info_logged => 1})
    ::Instana.tracer.log_error(Exception.new("Low level tracing api error"))
    ::Instana.tracer.log_end(:test_trace, {:close_one => 1})

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count

    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?
    assert t.has_error?
  end

  def test_instana_headers_in_response
    ::Instana.processor.clear!
    ::Instana.tracer.start_or_continue_trace(:test_trace, {:one => 1}) do
      sleep 0.5
    end

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count
    t = traces.first
    assert_equal 1, t.spans.size
    assert t.valid?

    first_span = t.spans.first
    assert_equal :test_trace, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_id_to_header_conversion
    # Test passing a standard Integer ID
    original_id = rand(2**32..2**64-1)
    converted_id = Instana.tracer.id_to_header(original_id)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert !converted_id[/\H/]

    # Test passing a standard Integer ID as a String
    original_id = rand(2**32..2**64-1).to_s
    converted_id = Instana.tracer.id_to_header(original_id)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert !converted_id[/\H/]
  end

  def test_id_to_header_conversion_with_bogus_id
    # Test passing an empty String
    converted_id = Instana.tracer.id_to_header('')

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == "0"

    # Test passing a nil
    converted_id = Instana.tracer.id_to_header(nil)

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == ''

    # Test passing an Array
    converted_id = Instana.tracer.id_to_header([])

    # Assert that it is a string and there are no non-hex characters
    assert converted_id.is_a?(String)
    assert converted_id == ''
  end

  def test_header_to_id_conversion
    # Get a hex string to test against & convert
    header_id = Instana.tracer.id_to_header(rand(2**32..2**64-1))
    converted_id = Instana.tracer.header_to_id(header_id)

    # Assert that it is an Integer
    assert converted_id.is_a?(Integer)
    assert converted_id > 0
  end

  def test_header_to_id_conversion_with_bogus_header
    # Bogus nil arg
    bogus_result = Instana.tracer.header_to_id(nil)
    assert_equal 0, bogus_result

    # Bogus Integer arg
    bogus_result = Instana.tracer.header_to_id(1234)
    assert_equal 0, bogus_result

    # Bogus Array arg
    bogus_result = Instana.tracer.header_to_id([1234])
    assert_equal 0, bogus_result
  end

  def test_id_conversion_back_and_forth
    # id --> header --> id
    original_id = rand(2**32..2**64-1)
    header_id = Instana.tracer.id_to_header(original_id)
    converted_back_id = Instana.tracer.header_to_id(header_id)
    assert original_id == converted_back_id

    # header --> id --> header
    original_header_id = "c025ee93b1aeda7b"
    id = Instana.tracer.header_to_id(original_header_id)
    converted_back_header_id = Instana.tracer.id_to_header(id)
    assert_equal original_header_id, converted_back_header_id
  end
end
