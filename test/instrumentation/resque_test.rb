require 'test_helper'
require_relative "../jobs/resque_job_1"
require_relative "../jobs/resque_job_2"

::Resque.redis = 'mazzo:6379'

class ResqueClientTest < Minitest::Test
  def setup
    clear_all!
  end

  def teardown
  end

  def test_enqueue
    ::Instana.tracer.start_or_continue_trace('resque-client_test') do
      ::Resque.enqueue(ResqueWorkerJob1)
    end

    traces = Instana.processor.queued_traces
    assert_equal 2, traces.count
  end

  def test_dequeue
    ::Instana.tracer.start_or_continue_trace('resque-client_test', '', {}) do
      ::Resque.dequeue(ResqueWorkerJob2, { :generate => :farfalla })
    end

    traces = Instana.processor.queued_traces
    assert_equal 2, traces.count, "trace count"
  end
end
