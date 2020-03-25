require 'test_helper'
require_relative "../jobs/resque_fast_job"
require_relative "../jobs/resque_error_job"
require 'resque'

if ENV.key?('REDIS_URL')
  ::Resque.redis = ENV['REDIS_URL']
elsif ENV.key?('REDIS_URL')
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
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test') do
      ::Resque.enqueue(FastJob)
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = find_first_span_by_name(spans, :'resque-client_test')
    resque_span = find_first_span_by_name(spans, :'resque-client')

    assert_equal :'resque-client_test', sdk_span[:data][:sdk][:name]

    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)
  end

  def test_enqueue_to
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test') do
      ::Resque.enqueue_to(:critical, FastJob)
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = find_first_span_by_name(spans, :'resque-client_test')
    resque_span = find_first_span_by_name(spans, :'resque-client')

    assert_equal :'resque-client_test', sdk_span[:data][:sdk][:name]
    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)
  end

  def test_dequeue
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test', '', {}) do
      ::Resque.dequeue(FastJob, { :generate => :farfalla })
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = find_first_span_by_name(spans, :'resque-client_test')
    resque_span = find_first_span_by_name(spans, :'resque-client')

    assert_equal :'resque-client_test', sdk_span[:data][:sdk][:name]
    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)
  end

  def test_worker_job
    Resque::Job.create(:critical, FastJob)
    @worker.work(0)

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    resque_span = spans[2]
    redis1_span = spans[1]
    redis2_span = spans[0]

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

    spans = ::Instana.processor.queued_spans
    assert_equal 5, spans.length

    resque_span = find_first_span_by_name(spans, :'resque-worker')

    assert_equal :'resque-worker', resque_span[:n]
    assert_equal true, resque_span.key?(:error)
    assert_equal 1, resque_span[:ec]
    assert_equal "ErrorJob", resque_span[:data][:'resque-worker'][:job]
    assert_equal "critical", resque_span[:data][:'resque-worker'][:queue]
    assert_equal "Exception: Silly Rabbit, Trix are for kids.", resque_span[:data][:'resque-worker'][:error]
    assert_equal Array, resque_span[:stack].class
  end
end
