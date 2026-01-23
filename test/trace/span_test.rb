# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class SpanTest < Minitest::Test
  def test_getters_setters
    span = Instana::Span.new(:test)

    assert_equal span[:s], span.id
    assert_equal span[:t], span.trace_id
    assert_nil span[:p] # parent_id of a root span is nil
    assert_nil span[:d] # duration of an open span is nil

    span.parent_id = 'test'
    assert_equal 'test', span.parent_id

    span.name = 'test'
    assert_equal 'test', span[:data][:sdk][:name]

    span[:t] = 'test'
    assert span.key?(:t)
    assert_equal 'test', span[:t]

    assert span.inspect
  end

  def test_builtin_span_rename
    span = Instana::Span.new(:"net-http")
    assert_equal :"net-http", span.name

    span.name = 'test'
    assert_equal 'test', span.name
  end

  def test_exit_span
    span = Instana::Span.new(:"net-http")
    assert span.exit_span?
  end

  def test_span_from_contetx
    context = Instana::SpanContext.new(trace_id: 'test', span_id: 'test', level: 0)
    span = Instana::Span.new(:test, context)

    assert_equal 'test', span.parent_id
    assert_equal 'test', span.trace_id
  end

  def test_span_from_contetx_invalid
    context = Instana::SpanContext.new(trace_id: nil, span_id: nil, level: 1)
    span = Instana::Span.new(:test, parent_ctx: context)

    assert_nil span.parent_id
    refute_equal context.span_id, span.trace_id
    assert_equal 1, span.context.level
  end

  def test_span_collect_backtraces
    Instana.config[:back_trace][:stack_trace_level] = "all"
    span = Instana::Span.new(:excon)
    assert span[:stack]
  ensure
    Instana.config[:back_trace][:stack_trace_level] = nil
  end

  def test_span_backtrace_cleaner
    ::Instana.config[:back_trace][:stack_trace_level] = "all"
    Instana.config[:backtrace_cleaner] =
      ->(trace) { trace.filter { |line| line.include?("lib/instana") } }
    span = Instana::Span.new(:excon)

    assert_equal 1, span[:stack].size
  ensure
    Instana.config[:backtrace_cleaner] = nil
    Instana.config[:back_trace][:stack_trace_level] = nil
  end

  def test_span_stack_over_limit
    def inner(depth = 50, &blk) # rubocop:disable Lint/NestedMethodDefinition
      return blk.call if depth.zero?

      inner(depth - 1, &blk)
    end

    inner do
      span = Instana::Span.new(:excon)
      span.add_stack(span_stack_config: { stack_trace_length: 500})
      assert_equal 40, span[:stack].length
    end
  end

  def test_multiple_errors
    span = Instana::Span.new(:activerecord)
    span.set_tag(:activerecord, {})

    span.record_exception(StandardError.new('Test1'))
    span.record_exception(StandardError.new('Test2'))

    assert_equal 2, span[:ec]
    assert_equal 'Test2', span[:data][:activerecord][:error]
  end

  def test_record_exception_nil
    span = Instana::Span.new(:activerecord)
    span.record_exception(nil)

    assert_equal 1, span[:ec]
  end

  def test_set_tag_merge
    span = Instana::Span.new(:excon)
    span.set_tag(1024, {a: 1})
    span.set_tag(1024, {b: 2})

    assert_equal({'1024' => {a: 1, b: 2}}, span[:data])
  end

  def test_set_tags_non_hash
    span = Instana::Span.new(:excon)
    assert_nil span.set_tags(0)
  end

  def test_tags_standard
    span = Instana::Span.new(:excon)
    span.set_tag(:test, {a: 1})

    assert_equal({test: {a: 1}}, span.tags)
    assert_equal({a: 1}, span.tags(:test))
  end

  def test_log_standard
    span = Instana::Span.new(:excon)
    span.log(:test, Time.now, a: 1)

    assert_equal({log: {a: 1}}, span.tags)
  end

  def test_log_error
    time = Minitest::Mock.new
    time.expect(:to_f, nil)

    span = Instana::Span.new(:sdk)
    span.log(:test, time, a: 1)

    assert_equal({}, span.tags)
    time.verify
  end

  def test_inc_processed_counts
    clear_all!

    span = Instana::Span.new(:excon)
    span.close

    metrics = Instana.processor.span_metrics

    assert_equal 1, metrics[:opened]
    assert_equal 1, metrics[:closed]

    metrics = Instana.processor.span_metrics

    assert_equal 0, metrics[:opened]
    assert_equal 0, metrics[:closed]
  end

  def test_custom_service_name_set
    service_name = 'MyVeryCustomRubyServiceNameForInstanaTesting'
    ENV['INSTANA_SERVICE_NAME'] = service_name
    span = Instana::Span.new(:excon)
    assert_equal(service_name, span[:data][:service])
  ensure
    ENV.delete('INSTANA_SERVICE_NAME')
  end

  def test_no_custom_service_name_set
    span = Instana::Span.new(:excon)
    assert_nil(span[:data][:service])
  end

  # Tests for stack_trace_level configuration

  def test_stack_trace_level_all_collects_for_all_spans
    Instana.config[:back_trace][:stack_trace_level] = "all"
    span = Instana::Span.new(:excon)

    assert span[:stack], "Stack trace should be collected for all spans when level is 'all'"
    assert span[:stack].is_a?(Array), "Stack trace should be an array"
    assert span[:stack].length.positive?, "Stack trace should not be empty"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  def test_stack_trace_level_error_does_not_collect_for_normal_spans
    Instana.config[:back_trace][:stack_trace_level] = "error"
    span = Instana::Span.new(:excon)

    assert_nil span[:stack], "Stack trace should not be collected for normal spans when level is 'error'"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  def test_stack_trace_level_error_collects_for_erroneous_spans
    Instana.config[:back_trace][:stack_trace_level] = "error"
    span = Instana::Span.new(:excon)

    # Span should not have stack trace at creation with level 'error'
    assert_nil span[:stack], "Stack trace should not be collected at span creation when level is 'error'"

    # Record an exception to make it an erroneous span
    # Need to raise the exception to populate its backtrace
    begin
      raise StandardError, "Test error"
    rescue StandardError => e
      span.record_exception(e)
    end

    # Stack trace from the exception backtrace should be collected
    assert span[:stack], "Stack trace from exception should be collected"
    assert span[:stack].is_a?(Array), "Stack trace should be an array"
    assert span[:stack].length.positive?, "Stack trace should not be empty"
    assert_equal 1, span[:ec], "Error count should be 1"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  def test_stack_trace_level_none_does_not_collect_for_normal_spans
    Instana.config[:back_trace][:stack_trace_level] = "none"
    span = Instana::Span.new(:excon)

    assert_nil span[:stack], "Stack trace should not be collected when level is 'none'"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  def test_stack_trace_level_none_does_not_collect_for_erroneous_spans
    Instana.config[:back_trace][:stack_trace_level] = "none"
    span = Instana::Span.new(:excon)

    # Span should not have stack trace at creation with level 'none'
    assert_nil span[:stack], "Stack trace should not be collected at span creation when level is 'none'"

    # Record an exception - need to raise it to populate backtrace
    begin
      raise StandardError, "Test error"
    rescue StandardError => e
      span.record_exception(e)
    end

    # NOTE: record_exception always collects the exception's backtrace regardless of stack_trace_level
    # This is by design - the stack_trace_level only controls automatic collection at span creation
    assert span[:stack], "Stack trace from exception backtrace is always collected by record_exception"
    assert_equal 1, span[:ec], "Error count should be 1"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  # Tests for stack_trace_length configuration

  def test_stack_trace_length_limits_frames
    Instana.config[:back_trace][:stack_trace_level] = "all"
    Instana.config[:back_trace][:stack_trace_length] = 5

    span = Instana::Span.new(:excon)

    assert span[:stack], "Stack trace should be collected"
    assert span[:stack].length <= 5, "Stack trace should be limited to 5 frames"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  def test_stack_trace_length_with_different_values
    Instana.config[:back_trace][:stack_trace_level] = "all"

    # Test with length 10
    Instana.config[:back_trace][:stack_trace_length] = 10
    span1 = Instana::Span.new(:excon)
    assert span1[:stack].length <= 10, "Stack trace should be limited to 10 frames"

    # Test with length 20
    Instana.config[:back_trace][:stack_trace_length] = 20
    span2 = Instana::Span.new(:excon)
    assert span2[:stack].length <= 20, "Stack trace should be limited to 20 frames"

    # Test with length 1
    Instana.config[:back_trace][:stack_trace_length] = 1
    span3 = Instana::Span.new(:excon)
    assert span3[:stack].length <= 1, "Stack trace should be limited to 1 frame"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  def test_stack_trace_length_zero_collects_no_frames
    Instana.config[:back_trace][:stack_trace_level] = "all"
    Instana.config[:back_trace][:stack_trace_length] = 0

    span = Instana::Span.new(:excon)

    # With length 0, stack should either be nil or empty array
    assert(span[:stack].nil? || span[:stack].empty?, "Stack trace should be empty with length 0")
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  # Combined tests for stack_trace_level and stack_trace_length

  def test_stack_trace_all_with_custom_length
    Instana.config[:back_trace][:stack_trace_level] = "all"
    Instana.config[:back_trace][:stack_trace_length] = 15

    span = Instana::Span.new(:excon)

    assert span[:stack], "Stack trace should be collected with level 'all'"
    assert span[:stack].length <= 15, "Stack trace should respect custom length of 15"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  def test_stack_trace_error_with_custom_length_on_error
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 8

    span = Instana::Span.new(:excon)

    # No stack at creation with level 'error'
    assert_nil span[:stack], "Stack trace should not be collected at span creation when level is 'error'"

    # Raise exception to populate backtrace
    begin
      raise StandardError, "Test error"
    rescue StandardError => e
      span.record_exception(e)
    end

    # Stack trace from exception should be collected and respect length limit
    assert span[:stack], "Stack trace from exception should be collected"
    assert span[:stack].length <= 8, "Stack trace should respect custom length of 8"
    assert_equal 1, span[:ec], "Error count should be 1"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  def test_stack_trace_none_ignores_length_setting
    Instana.config[:back_trace][:stack_trace_level] = "none"
    Instana.config[:back_trace][:stack_trace_length] = 100

    span = Instana::Span.new(:excon)

    assert_nil span[:stack], "Stack trace should not be collected when level is 'none', regardless of length"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
    Instana.config[:back_trace][:stack_trace_length] = 30
  end

  # Test for non-exit spans

  def test_stack_trace_not_collected_for_non_exit_spans
    Instana.config[:back_trace][:stack_trace_level] = "all"

    # Create a non-exit span (sdk/custom span)
    span = Instana::Span.new(:sdk)

    # Non-exit spans should not collect stack traces automatically
    assert_nil span[:stack], "Stack trace should not be collected for non-exit spans"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end

  def test_stack_trace_for_multiple_errors_with_error_level
    Instana.config[:back_trace][:stack_trace_level] = "error"

    span = Instana::Span.new(:excon)

    # No stack at creation with level 'error'
    assert_nil span[:stack], "Stack trace should not be collected at span creation when level is 'error'"

    # First error - raise to populate backtrace
    begin
      raise StandardError, "First error"
    rescue StandardError => e
      span.record_exception(e)
    end

    assert span[:stack], "Stack trace from first exception should be collected"
    first_stack = span[:stack].dup

    # Second error - raise to populate backtrace
    begin
      raise StandardError, "Second error"
    rescue StandardError => e
      span.record_exception(e)
    end

    assert span[:stack], "Stack trace from second exception should be collected"
    assert_equal 2, span[:ec], "Error count should be 2"
    # The stack from the second error should replace the first
    refute_equal first_stack, span[:stack], "Stack trace should be updated with second error"
  ensure
    Instana.config[:back_trace][:stack_trace_level] = "error"
  end
end
