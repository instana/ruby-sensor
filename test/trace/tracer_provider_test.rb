# (c) Copyright IBM Corp. 2025
# (c) Copyright Instana Inc. 2025

require 'test_helper'
require 'instana/trace/tracer_provider'
require 'instana/trace/export'

class TracerProviderTest < Minitest::Test
  def setup
    @tracer_provider = Instana.tracer_provider
  end

  def test_tracer
    # This tests the global tracer is the same as tracer from tracer_provider
    assert_equal Instana.tracer, @tracer_provider.tracer("instana_tracer")
  end

  def test_shutdown_with_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    timeout = 10
    result = @tracer_provider.shutdown(timeout: timeout)
    assert_equal Instana::Trace::Export::SUCCESS, result
    @span_processors = @tracer_provider.instance_variable_get(:@span_processors)
    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
    assert @tracer_provider.instance_variable_get(:@stopped)
  end

  def test_shutdown_without_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    # @tracer = @tracer_provider.tracer('test_shutdown_without_timeout')
    result = @tracer_provider.shutdown
    assert_equal Instana::Trace::Export::SUCCESS, result

    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
    assert @tracer_provider.instance_variable_get(:@stopped)
  end

  def test_shutdown_called_multiple_times
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    # @tracer = @tracer_provider.tracer('test_shutdown_called_multiple_times')

    result1 = @tracer_provider.shutdown
    result2 = @tracer_provider.shutdown

    assert_equal Instana::Trace::Export::SUCCESS, result1
    assert_equal Instana::Trace::Export::FAILURE, result2

    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
    assert @tracer_provider.instance_variable_get(:@stopped)
  end

  def test_shutdown_with_zero_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    # @tracer = @tracer_provider.tracer('test_shutdown_with_zero_timeout')
    timeout = 0
    result = @tracer_provider.shutdown(timeout: timeout)
    assert_equal Instana::Trace::Export::TIMEOUT, result

    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
    assert @tracer_provider.instance_variable_get(:@stopped)
  end

  def test_force_flush_with_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    timeout = 10
    result = @tracer_provider.force_flush(timeout: timeout)
    assert_equal Instana::Trace::Export::SUCCESS, result
    @span_processors = @tracer_provider.instance_variable_get(:@span_processors)
    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
  end

  def test_force_flush_without_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    result = @tracer_provider.force_flush
    assert_equal Instana::Trace::Export::SUCCESS, result

    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
  end

  def test_force_flush_with_zero_timeout
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    timeout = 0
    result = @tracer_provider.force_flush(timeout: timeout)
    assert_equal Instana::Trace::Export::TIMEOUT, result

    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
    assert_equal [Instana::Trace::Export::SUCCESS], @tracer_provider.instance_variable_get(:@span_processors).map(&:shutdown)
  end

  def test_add_span_processor_after_shutdown
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    @tracer_provider.add_span_processor(DummyProcessor.new)
    @tracer_provider.shutdown
    result = @tracer_provider.add_span_processor(DummyProcessor.new)
    assert_nil result
    # No new span processor was added as tracer_provider is stopped
    assert_equal 1, @tracer_provider.instance_variable_get(:@span_processors).length
  end

  def test_internal_start_span_untraced
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    Minitest::Mock.new
    result = @tracer_provider.internal_start_span('test_span', 'kind', {}, [], Time.now, nil, @instrumentation_scope)
    assert_instance_of(Instana::Span, result)
    # Todo add proper testcase
  end

  def test_internal_start_span_traced
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    Minitest::Mock.new
    result = @tracer_provider.internal_start_span('test_span', 'kind', {}, [], Time.now, nil, @instrumentation_scope)
    assert_instance_of(Instana::Span, result)
    # Todo add proper testcase
  end

  def test_internal_start_span_stopped
    @tracer_provider = ::Instana::Trace::TracerProvider.new
    Minitest::Mock.new
    result = @tracer_provider.internal_start_span('test_span', 'kind', {}, [], Time.now, nil, @instrumentation_scope)
    assert_instance_of(Instana::Span, result)
    # Todo add proper testcase
  end
end

class DummyProcessor
  def initialize; end

  def shutdown(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
    Instana::Trace::Export::SUCCESS
  end

  def force_flush(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
    Instana::Trace::Export::SUCCESS
  end
end
