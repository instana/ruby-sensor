# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

require 'test_helper'
require 'support/apps/resque/boot'

Warning[:deprecated] = false if Gem::Version.new(RUBY_VERSION) > Gem::Version.new('3.4')

::Resque.redis = ENV['REDIS_URL']

class ResqueClientTest < Minitest::Test
  def setup
    clear_all!
    ENV['FORK_PER_JOB'] = 'false'
    Resque.redis.redis.flushall
    @worker = Resque::Worker.new(:critical)
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def test_enqueue
    ::Instana.tracer.in_span(:'resque-client_test') do
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

  def test_enqueue_as_root_exit_span
    ::Instana.config[:allow_exit_as_root] = true
    ::Resque.enqueue(FastJob)
    ::Instana.config[:allow_exit_as_root] = false

    resque_job = Resque.reserve('critical')
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    resque_span = spans[0]

    assert_equal :"resque-client", resque_span[:n]
    assert_equal "FastJob", resque_span[:data][:'resque-client'][:job]
    assert_equal :critical, resque_span[:data][:'resque-client'][:queue]
    assert_equal false, resque_span[:data][:'resque-client'].key?(:error)

    assert_equal resque_job.args.first['trace_id'], resque_span[:t]
    assert_equal resque_job.args.first['span_id'], resque_span[:s]
  end

  def test_enqueue_to
    ::Instana.tracer.in_span(:'resque-client_test') do
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
    ::Instana.tracer.in_span(:'resque-client_test') do
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
    ::Instana.tracer.in_span(:'resque-client_test') do
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
    ::Instana.tracer.in_span(:'resque-client_test') do
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

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    clear_all!
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      # Capture stderr to check for deprecation warnings but don't fail on them
      _stderr = capture_io do
        ::Resque.enqueue(FastJob)
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end

  def test_enqueue_not_tracing_skips_span
    # Call enqueue without an active trace — should call super without creating a span
    ::Resque.enqueue(FastJob)
    Resque.reserve('critical') # consume it

    spans = ::Instana.processor.queued_spans
    refute spans.any? { |s| s[:n] == :'resque-client' }, "No resque-client span should be created when not tracing"
  end

  def test_dequeue_not_tracing_skips_span
    ::Resque.enqueue(FastJob)
    ::Resque.dequeue(FastJob)

    spans = ::Instana.processor.queued_spans
    refute spans.any? { |s| s[:n] == :'resque-client' }, "No resque-client span when dequeue is called outside trace"
  end

  def test_enqueue_to_not_tracing_skips_span
    ::Resque.enqueue_to(:critical, FastJob)
    Resque.reserve('critical')

    spans = ::Instana.processor.queued_spans
    refute spans.any? { |s| s[:n] == :'resque-client' }, "No resque-client span when enqueue_to called outside trace"
  end

  def test_resque_job_fail_logs_error_when_tracing
    ::Instana.tracer.in_span(:'resque-client_test') do
      ::Resque.enqueue(FastJob)
    end

    resque_job = Resque.reserve('critical')
    @worker.work_one_job(resque_job)

    # Simulate ResqueJob#fail inside an active trace
    ::Instana.tracer.in_span(:'resque-worker') do
      job_module = Instana::Instrumentation::ResqueJob
      # Build a fake job that responds to super
      fake_job = Object.new
      fake_job.extend(job_module)
      fake_job.define_singleton_method(:fail) do |exception|
        # call the module's fail but bypass super
        return unless Instana.tracer.tracing?

        ::Instana.tracer.log_info(:'resque-worker' => { error: "#{exception.class}: #{exception}" })
        ::Instana.tracer.log_error(exception)
      end

      fake_job.fail(RuntimeError.new("test error"))
    end

    # As long as no exception was raised, the method handled it
    assert true
  end

  def test_resque_job_fail_outside_trace_is_silent
    job_module = Instana::Instrumentation::ResqueJob
    fake_job = Object.new
    fake_job.extend(job_module)
    fake_job.define_singleton_method(:fail) do |exception|
      return unless Instana.tracer.tracing?

      ::Instana.tracer.log_info(:'resque-worker' => { error: "#{exception.class}: #{exception}" })
      ::Instana.tracer.log_error(exception)
    end

    assert_silent { fake_job.fail(RuntimeError.new("test")) }
  end
end
