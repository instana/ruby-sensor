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

  def test_config_defaults
    assert ::Instana.config[:active_job].is_a?(Hash)
    assert ::Instana.config[:active_job].key?(:enabled)
    assert_equal true, ::Instana.config[:active_job][:enabled]
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

    Instana.tracer.start_or_continue_trace(:peform_test) do
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
end
