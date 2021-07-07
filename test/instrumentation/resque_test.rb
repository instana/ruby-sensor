# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

require 'test_helper'
require 'support/apps/resque/boot'

::Resque.redis = ENV['REDIS_URL']

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

    resque_job = Resque.reserve('critical')
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = find_first_span_by_name(spans, :'resque-client_test')
    resque_span = find_first_span_by_name(spans, :'resque-client')

    assert_equal :'resque-client_test', sdk_span[:data][:sdk][:name]

    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)

    assert_equal resque_job.args.first['trace_id'], resque_span[:t]
    assert_equal resque_job.args.first['span_id'], resque_span[:s]
  end

  def test_enqueue_to
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test') do
      ::Resque.enqueue_to(:critical, FastJob)
    end

    resque_job = Resque.reserve('critical')
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    sdk_span = find_first_span_by_name(spans, :'resque-client_test')
    resque_span = find_first_span_by_name(spans, :'resque-client')

    assert_equal :'resque-client_test', sdk_span[:data][:sdk][:name]
    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)

    assert_equal resque_job.args.first['trace_id'], resque_span[:t]
    assert_equal resque_job.args.first['span_id'], resque_span[:s]
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
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test') do
      ::Resque.enqueue_to(:critical, FastJob)
    end

    resque_job = Resque.reserve('critical')
    @worker.work_one_job(resque_job)

    spans = ::Instana.processor.queued_spans
    assert_equal 5, spans.length

    client_span = spans[0]
    resque_span = spans[4]
    redis1_span = spans[3]
    redis2_span = spans[2]

    assert_equal :'resque-client', client_span[:n]

    assert_equal :'resque-worker', resque_span[:n]
    assert_equal client_span[:s], resque_span[:p]
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

  def test_worker_job_no_propagate
    ::Instana.config[:'resque-client'][:propagate] = false
    ::Instana.tracer.start_or_continue_trace(:'resque-client_test') do
      ::Resque.enqueue_to(:critical, FastJob)
    end

    resque_job = Resque.reserve('critical')
    @worker.work_one_job(resque_job)

    spans = ::Instana.processor.queued_spans
    assert_equal 5, spans.length

    client_span = spans[0]
    resque_span = spans[4]
    redis1_span = spans[3]
    redis2_span = spans[2]

    assert_equal :'resque-client', client_span[:n]

    assert_equal :'resque-worker', resque_span[:n]
    refute_equal client_span[:s], resque_span[:p]
    assert_equal false, resque_span.key?(:error)
    assert_equal false, resque_span.key?(:ec)
    assert_equal "FastJob", resque_span[:data][:'resque-worker'][:job]
    assert_equal "critical", resque_span[:data][:'resque-worker'][:queue]
    assert_equal false, resque_span[:data][:'resque-worker'].key?(:error)

    assert_equal :redis, redis1_span[:n]
    assert_equal "SET", redis1_span[:data][:redis][:command]
    assert_equal :redis, redis2_span[:n]
    assert_equal "SET", redis2_span[:data][:redis][:command]
  ensure
    ::Instana.config[:'resque-client'][:propagate] = true
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
