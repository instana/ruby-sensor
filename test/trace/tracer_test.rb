# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'

class TracerTest < Minitest::Test
  def test_that_it_has_a_valid_tracer
    refute_nil ::Instana.tracer
    assert ::Instana.tracer.is_a?(::Instana::Tracer)
  end

  def test_obey_tracing_config
    clear_all!

    ::Instana.config[:tracing][:enabled] = false
    assert_equal false, ::Instana.tracer.tracing?

    ::Instana.tracer.in_span(:rack, attributes: {:one => 1}) do
      assert_equal false, ::Instana.tracer.tracing?
    end

    ::Instana.config[:tracing][:enabled] = true
  end

  def test_basic_trace_block
    clear_all!

    assert_equal false, ::Instana.tracer.tracing?

    ::Instana.tracer.in_span(:rack, attributes: {:one => 1}) do
      assert_equal true, ::Instana.tracer.tracing?
      sleep 0.1
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span[:ts].is_a?(Integer)
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(100, 130)
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert_equal ::Instana.agent.source, first_span[:f]
  end

  def test_exotic_tag_types
    clear_all!

    assert_equal false, ::Instana.tracer.tracing?

    ipv4 = '111.111.111.111'

    ::Instana.tracer.in_span(:rack, attributes: {:ipaddr => ipv4}) do
      assert_equal true, ::Instana.tracer.tracing?
      sleep 0.1
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span[:ts].is_a?(Integer)
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(100, 130)
    assert first_span.key?(:data)
    assert first_span[:data].key?(:ipaddr)
    assert first_span[:data][:ipaddr].is_a?(String)
    assert first_span.key?(:f)
    assert_equal ::Instana.agent.source, first_span[:f]
  end

  def test_errors_are_properly_propagated
    clear_all!
    exception_raised = false
    begin
      ::Instana.tracer.in_span(:rack, attributes: {:one => 1}) do
        raise StandardError, 'Error in block - this should continue to propogate outside of tracing'
      end
    rescue StandardError
      exception_raised = true
    end

    assert exception_raised

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span[:ts].is_a?(Integer)
    assert first_span[:ts].positive?
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)
    assert first_span.key?(:data)
    assert_equal 1, first_span[:data][:one]
    assert first_span.key?(:f)
    assert_equal ::Instana.agent.source, first_span[:f]
    assert_equal first_span[:error], true
    assert_equal first_span[:ec], 1
  end

  def test_complex_trace_block
    clear_all!
    ::Instana.tracer.in_span(:rack, attributes: {:one => 1}) do
      sleep 0.2
      ::Instana.tracer.in_span(:sub_block, attributes: {:sub_two => 2}) do
        sleep 0.2
      end
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    sdk_span = find_first_span_by_name(spans, :sub_block)

    assert_equal rack_span[:n], :rack
    assert_nil rack_span[:p]
    assert_equal rack_span[:t], rack_span[:s]
    assert_equal rack_span[:data][:one], 1

    assert_equal sdk_span[:n], :sdk
    assert_equal sdk_span[:data][:sdk][:name], :sub_block
    assert_equal sdk_span[:data][:sdk][:type], :intermediate
    assert_equal sdk_span[:k], 3
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:sub_two], 2
  end

  def test_custom_complex_trace_block
    clear_all!
    ::Instana.tracer.in_span(:root_span, attributes: {:one => 1}) do
      sleep 0.2
      ::Instana.tracer.in_span(:sub_span, attributes: {:sub_two => 2}) do
        sleep 0.2
      end
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    root_span = find_first_span_by_name(spans, :root_span)
    sub_span = find_first_span_by_name(spans, :sub_span)

    assert_equal root_span[:n], :sdk
    assert_equal root_span[:data][:sdk][:name], :root_span
    assert_equal root_span[:data][:sdk][:type], :entry
    assert_equal root_span[:k], 1
    assert_nil root_span[:p]
    assert_equal root_span[:t], root_span[:s]
    assert_equal root_span[:data][:sdk][:custom][:tags][:one], 1

    assert_equal sub_span[:n], :sdk
    assert_equal sub_span[:data][:sdk][:name], :sub_span
    assert_equal sub_span[:data][:sdk][:type], :intermediate
    assert_equal sub_span[:k], 3
    assert_equal sub_span[:p], root_span[:s]
    assert_equal sub_span[:t], root_span[:t]
    assert_equal sub_span[:data][:sdk][:custom][:tags][:sub_two], 2
  end

  def test_basic_low_level_tracing
    clear_all!

    assert_equal false, ::Instana.tracer.tracing?
    # Start tracing
    span = ::Instana.tracer.start_span(:rack, attributes: {:one => 1})
    assert_equal true, ::Instana.tracer.tracing?
    span.set_tags({:info_logged => 1})
    # End tracing
    span.set_tags({:close_one => 1})
    span.finish
    assert_equal false, ::Instana.tracer.tracing?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
  end

  def test_complex_low_level_tracing
    clear_all!

    assert_equal false, ::Instana.tracer.tracing?

    # Start tracing
    span = ::Instana.tracer.start_span(:rack, attributes: {:one => 1})
    assert_equal true, ::Instana.tracer.tracing?
    span.set_tags({:info_logged => 1})

    # Start tracing a sub span with context propagation
    span1 = ::Instana::Trace.with_span(span) do
      ::Instana.tracer.start_span(:sub_task)
    end
    assert_equal true, ::Instana.tracer.tracing?
    span1.set_tags({:sub_task_info => 1})
    # Exit from the sub span
    span1.set_tags({:sub_task_exit_info => 1})

    span1.finish
    assert_equal true, ::Instana.tracer.tracing?

    # End tracing
    span.set_tags({:close_one => 1})
    span.finish
    assert_equal false, ::Instana.tracer.tracing?

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    sdk_span = find_first_span_by_name(spans, :sub_task)

    assert_equal :rack, rack_span[:n]
    assert rack_span.key?(:data)
    assert_equal rack_span[:data][:one], 1
    assert_equal rack_span[:data][:info_logged], 1
    assert_equal rack_span[:data][:close_one], 1

    assert rack_span.key?(:f)
    assert_equal ::Instana.agent.source, rack_span[:f]

    assert_equal sdk_span[:n], :sdk
    assert_equal sdk_span[:data][:sdk][:name], :sub_task
    assert_equal sdk_span[:data][:sdk][:type], :intermediate
    assert_equal sdk_span[:k], 3
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:sub_task_info], 1
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:sub_task_exit_info], 1
  end

  def test_block_tracing_error_capture
    clear_all!
    exception_raised = false
    begin
      ::Instana.tracer.in_span(:test_trace, attributes: {:one => 1}) do
        ::Instana.tracer.in_span(:test_trace_two) do
          raise StandardError, "Block exception test error"
        end
      end
    rescue StandardError
      exception_raised = true
    end

    assert exception_raised

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = spans.last

    assert_equal sdk_span[:n], :sdk
    assert_equal sdk_span[:data][:sdk][:name], :test_trace
    assert_equal sdk_span[:data][:sdk][:type], :entry
    assert_equal sdk_span[:k], 1
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:one], 1
    assert_equal sdk_span[:error], true
    assert_equal sdk_span[:ec], 1
    assert_equal sdk_span.key?(:stack), true
  end

  def test_low_level_error_logging
    clear_all!
    span = ::Instana.tracer.start_span(:test_trace, attributes: {:one => 1})
    span.set_tags({:info_logged => 1})
    span.record_exception(Exception.new("Low level tracing api error"))
    span.set_tags({:close_one => 1})
    span.finish
    # ::Instana.tracer.log_info({:info_logged => 1})
    # ::Instana.tracer.log_error(Exception.new("Low level tracing api error"))
    # ::Instana.tracer.log_end(:test_trace, {:close_one => 1})

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    sdk_span = spans[0]

    assert_equal sdk_span[:n], :sdk
    assert_equal sdk_span[:data][:sdk][:name], :test_trace
    assert_equal sdk_span[:data][:sdk][:type], :entry
    assert_equal sdk_span[:k], 1
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:one], 1
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:info_logged], 1
    assert_equal sdk_span[:data][:sdk][:custom][:tags][:close_one], 1
    assert_equal sdk_span[:error], true
    assert_equal sdk_span[:ec], 1
    assert_equal sdk_span.key?(:stack), false
  end

  def test_nil_returns
    clear_all!

    refute ::Instana.tracer.tracing?
    assert_nil ::Instana.tracer.log_entry(nil)
    assert_nil ::Instana.tracer.log_info(nil)
    assert_nil ::Instana.tracer.log_error(nil)
    assert_nil ::Instana.tracer.log_exit(nil)
    assert_nil ::Instana.tracer.log_end(nil)
    assert_nil ::Instana.tracer.log_async_entry(nil, nil)
    assert_nil ::Instana.tracer.context
  end

  def test_tracing_span
    clear_all!

    refute ::Instana.tracer.tracing_span?(:rack)
    ::Instana.tracer.start_span(:rack)
    assert ::Instana.tracer.tracing_span?(:rack)
  end

  def test_log_exit_warn_span_name
    logger = Minitest::Mock.new
    logger.expect(:warn, true, [String])

    subject = Instana::Tracer.new(nil, nil, ::Instana::Trace::TracerProvider.new, logger)

    subject.start_span(:sample)
    subject.log_exit(:roda)

    logger.verify
  end

  def test_log_end_warn_span_name
    clear_all!

    logger = Minitest::Mock.new
    logger.expect(:warn, true, [String])
    subject = Instana::Tracer.new(nil, nil, ::Instana::Trace::TracerProvider.new, logger)

    subject.start_span(:sample)
    subject.log_end(:roda)

    logger.verify
  end

  def test_log_entry_span
    clear_all!

    subject = Instana::Tracer.new(nil, nil, ::Instana::Trace::TracerProvider.new)
    span = Instana::Span.new(:rack)

    subject.log_entry(:sample, {}, ::Instana::Util.now_in_ms, span)
    assert subject.tracing?
    assert subject.current_span.parent, span
  end

  def test_log_entry_span_context
    clear_all!

    subject = Instana::Tracer.new(nil, nil, nil)
    span_context = Instana::SpanContext.new(trace_id: 'test', span_id: 'test')

    subject.log_entry(:sample, {}, ::Instana::Util.now_in_ms, span_context)
    assert subject.tracing?
    assert subject.current_span.context, span_context
  end

  def test_missing_class_super
    assert_raises NoMethodError do
      Instana::Tracer.invalid
    end
  end
end
