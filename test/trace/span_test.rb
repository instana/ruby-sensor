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
end
