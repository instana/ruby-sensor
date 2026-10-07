# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

require 'rails'
require 'active_job'

class RailsActiveJobTest < Minitest::Test
  class SampleJob < ActiveJob::Base
    queue_as :test_queue

    def perform(*args); end
  end

  def setup
    @test_adapter = ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::TestAdapter.new
    ActiveJob::Base.logger = Logger.new('/dev/null')

    clear_all!
  end

  def test_perform_now
    SampleJob.perform_now("test_perform_now")
    spans = ::Instana.processor.queued_spans

    server_span, *rest = spans
    assert_equal [], rest

    assert_equal :activejob, server_span[:n]
    assert_equal 'RailsActiveJobTest::SampleJob', server_span[:data][:activejob][:job]
    assert_equal :perform, server_span[:data][:activejob][:action]
    assert_equal 'test_queue', server_span[:data][:activejob][:queue]
  end

  def test_enqueue_perform
    # ActiveJob::QueueAdapters::TestAdapter.new doesn't work for this test on any version less than 6
    skip unless Rails::VERSION::MAJOR >= 6

    Instana.tracer.in_span(:peform_test) do
      SampleJob.perform_later("test_enqueue_perform")
    end

    job, *rest_jobs = @test_adapter.enqueued_jobs
    assert_equal [], rest_jobs

    ActiveJob::Base.execute(job)

    spans = ::Instana.processor.queued_spans
    client_span, _test_span, server_span, *rest = spans
    assert_equal [], rest

    assert_equal :activejob, server_span[:n]
    assert_equal 'RailsActiveJobTest::SampleJob', server_span[:data][:activejob][:job]
    assert_equal :perform, server_span[:data][:activejob][:action]

    assert_equal :activejob, client_span[:n]
    assert_equal 'RailsActiveJobTest::SampleJob', client_span[:data][:activejob][:job]
    assert_equal :enqueue, client_span[:data][:activejob][:action]
    assert_equal 'test_queue', server_span[:data][:activejob][:queue]

    assert_equal client_span[:t], server_span[:t]
    assert_equal client_span[:s], server_span[:p]
  end

  def test_enqueue_with_suppressed_level_propagates_to_perform
    skip unless Rails::VERSION::MAJOR >= 6

    # Enqueue under a level-0 (suppressed) span so the serialised context carries level: 0
    suppressed_ctx = ::Instana::SpanContext.new(level: 0)
    ::Instana::Trace.with_span(OpenTelemetry::Trace.non_recording_span(suppressed_ctx)) do
      Instana.tracer.in_span(:suppressed_test) do
        SampleJob.perform_later("test_suppressed_level")
      end
    end

    job, *rest_jobs = @test_adapter.enqueued_jobs
    assert_equal [], rest_jobs

    # Capture the SpanContext reconstructed on the perform side
    captured_level = nil
    SampleJob.class_eval do
      alias_method :orig_perform, :perform
      define_method(:perform) do |*args|
        captured_level = ::Instana.tracer.context&.level
        orig_perform(*args)
      end
    end

    ActiveJob::Base.execute(job)

    SampleJob.class_eval { alias_method :perform, :orig_perform }

    assert_equal 0, captured_level
  end

  def test_extract_context_from_otel_headers_traceparent
    job = SampleJob.new
    job.instance_variable_set(:@__otel_headers, {
                                'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
                              })
    job.define_singleton_method(:__otel_headers) { @__otel_headers }

    ctx = ::Instana::Instrumentation::ActiveJob.extract_context(job)

    refute_nil ctx
    assert_equal ::Instana::Util.header_to_id('a3ce929d0e0e4736'), ctx.trace_id
    assert_equal ::Instana::Util.header_to_id('00f067aa0ba902b7'), ctx.span_id
    assert_equal 1, ctx.level
  end

  def test_extract_context_from_otel_headers_with_tracestate_in
    job = SampleJob.new
    job.instance_variable_set(:@__otel_headers, {
                                'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
                                'tracestate' => 'ro=xyz,in=1234567890abcdef;fedcba0987654321'
                              })
    job.define_singleton_method(:__otel_headers) { @__otel_headers }

    ctx = ::Instana::Instrumentation::ActiveJob.extract_context(job)

    refute_nil ctx
    assert_equal ::Instana::Util.header_to_id('1234567890abcdef'), ctx.trace_id
    assert_equal ::Instana::Util.header_to_id('fedcba0987654321'), ctx.span_id
    assert_equal 1, ctx.level
  end

  def test_extract_context_from_otel_headers_suppressed_flags
    job = SampleJob.new
    job.instance_variable_set(:@__otel_headers, {
                                'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00'
                              })
    job.define_singleton_method(:__otel_headers) { @__otel_headers }

    ctx = ::Instana::Instrumentation::ActiveJob.extract_context(job)

    refute_nil ctx
    assert_equal 0, ctx.level
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        SampleJob.perform_now("test_agent_not_ready")
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end
end
