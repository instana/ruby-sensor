require 'test_helper'
require_relative "../jobs/resque_fast_job"
require_relative "../jobs/resque_error_job"
require 'resque'

if ENV.key?('REDIS_URL')
  ::Resque.redis = ENV['REDIS_URL']
else
  ::Resque.redis = 'localhost:6379'
end

class ResqueClientTest < Minitest::Test
  def setup
    clear_all!
    ENV['FORK_PER_JOB'] = 'false'
    Resque.redis.redis.flushall
    @worker = Resque::Worker.new(:critical)
  end

  def teardown
  end

  def test_enqueue
    ::Instana.tracer.start_or_continue_trace('resque-client_test') do
      ::Resque.enqueue(FastJob)
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    assert_equal :'resque-client_test', spans[0][:data][:sdk][:name]

    assert_equal :"resque-client", spans[1][:n]
    assert_equal "FastJob", spans[1][:data][:'resque-client'][:job]
    assert_equal :critical, spans[1][:data][:'resque-client'][:queue]
    assert_equal false, spans[1][:data][:'resque-client'].key?(:error)

    assert_equal :redis, spans[2][:n]
  end

  def test_enqueue_to
    ::Instana.tracer.start_or_continue_trace('resque-client_test') do
      ::Resque.enqueue_to(:critical, FastJob)
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    assert_equal :'resque-client_test', spans[0][:data][:sdk][:name]
    assert_equal :"resque-client", spans[1][:n]
    assert_equal "FastJob", spans[1][:data][:'resque-client'][:job]
    assert_equal :critical, spans[1][:data][:'resque-client'][:queue]
    assert_equal false, spans[1][:data][:'resque-client'].key?(:error)
    assert_equal :redis, spans[2][:n]
  end

  def test_dequeue
    ::Instana.tracer.start_or_continue_trace('resque-client_test', '', {}) do
      ::Resque.dequeue(FastJob, { :generate => :farfalla })
    end

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    assert_equal :'resque-client_test', spans[0][:data][:sdk][:name]
    assert_equal :"resque-client", spans[1][:n]
    assert_equal "FastJob", spans[1][:data][:'resque-client'][:job]
    assert_equal :critical, spans[1][:data][:'resque-client'][:queue]
    assert_equal false, spans[1][:data][:'resque-client'].key?(:error)
    assert_equal :redis, spans[2][:n]
  end

  def test_worker_job
    Resque::Job.create(:critical, FastJob)
    @worker.work(0)

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length

    spans = traces[0].spans.to_a
    assert_equal 3, spans.count

    resque_span = spans[0]
    redis1_span = spans[1]
    redis2_span = spans[2]

    assert_equal :'resque-worker', resque_span[:n]
    assert_equal false, resque_span.key?(:error)
    assert_equal false, resque_span.key?(:ec)
    assert_equal "FastJob", resque_span[:data][:'resque-worker'][:job]
    assert_equal "critical", resque_span[:data][:'resque-worker'][:queue]
    assert_equal false, resque_span[:data][:'resque-worker'].key?(:error)

    assert_equal :redis, redis1_span[:n]
    assert_equal "SET", redis1_span[:data][:redis][:command]
    assert_equal :redis, redis2_span[:n]
    assert_equal "SET", redis2_span[:data][:redis][:command]
  end

  def test_worker_error_job
    Resque::Job.create(:critical, ErrorJob)
    @worker.work(0)

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length

    spans = traces[0].spans.to_a
    resque_span = spans[0]
    assert_equal 5, spans.count

    assert_equal :'resque-worker', resque_span[:n]
    assert_equal true, resque_span.key?(:error)
    assert_equal 1, resque_span[:ec]
    assert_equal "ErrorJob", resque_span[:data][:'resque-worker'][:job]
    assert_equal "critical", resque_span[:data][:'resque-worker'][:queue]
    assert_equal "Exception: Silly Rabbit, Trix are for kids.", resque_span[:data][:'resque-worker'][:error]
    assert_equal Array, resque_span[:stack].class
  end
end
