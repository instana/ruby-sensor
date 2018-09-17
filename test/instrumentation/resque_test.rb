require 'test_helper'
require_relative "../jobs/resque_job_1"
require_relative "../jobs/resque_job_2"
require 'resque'

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
    assert_equal 1, traces.count

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    assert_equal :'resque-client_test', spans[0][:data][:sdk][:name]
    assert_equal :"resque-client", spans[1][:n]
    assert_equal :redis, spans[2][:n]
  end

  def test_dequeue
    ::Instana.tracer.start_or_continue_trace('resque-client_test', '', {}) do
      ::Resque.dequeue(ResqueWorkerJob2, { :generate => :farfalla })
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.count

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    assert_equal :'resque-client_test', spans[0][:data][:sdk][:name]
    assert_equal :"resque-client", spans[1][:n]
    assert_equal :redis, spans[2][:n]
  end
end
