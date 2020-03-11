require 'test_helper'

class SidekiqClientTest < Minitest::Test
  def setup
    Sidekiq.configure_client do |config|
      config.redis = { url: ENV["REDIS_URL"] }
    end
    ::Sidekiq::Queue.new('some_random_queue').clear
  end

  def test_config_defaults
    assert ::Instana.config[:'sidekiq-client'].is_a?(Hash)
    assert ::Instana.config[:'sidekiq-client'].key?(:enabled)
    assert_equal true, ::Instana.config[:'sidekiq-client'][:enabled]
  end

  def test_enqueue
    clear_all!
    Instana.tracer.start_or_continue_trace(:sidekiqtests) do
      disable_redis_instrumentation
      ::Sidekiq::Client.push(
        'queue' => 'some_random_queue',
        'class' => ::SidekiqJobOne,
        'args' => [1, 2, 3],
        'retry' => false
      )
      enable_redis_instrumentation
    end

    queue = ::Sidekiq::Queue.new('some_random_queue')
    job = queue.first

    assert_job_enqueued(job)
    assert_normal_trace_recorded(job)
  end

  def test_enqueue_failure
    clear_all!

    Instana.tracer.start_or_continue_trace(:sidekiqtests) do
      disable_redis_instrumentation
      add_sidekiq_exception_middleware
      begin
        ::Sidekiq::Client.push(
          'queue' => 'some_random_queue',
          'class' => ::SidekiqJobTwo,
          'args' => [1, 2, 3],
          'retry' => false
        )
      rescue; end
      enable_redis_instrumentation
      remove_sidekiq_exception_middleware
    end

    queue = ::Sidekiq::Queue.new('some_random_queue')
    assert_equal 0, queue.size

    assert_failure_trace_recorded
  end

  private

  def assert_job_enqueued(job)
    job_message = JSON.parse(job.value)

    assert_equal 'some_random_queue', job_message['queue']
    assert_equal 'SidekiqJobOne', job_message['class']
    assert_equal [1, 2, 3], job_message['args']
    assert_equal false, job_message['retry']
    assert_equal false, job_message['X-Instana-T'].nil?
    assert_equal false, job_message['X-Instana-S'].nil?
  end

  def assert_normal_trace_recorded(job)
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    assert_equal first_span[:s], second_span[:p]
    validate_sdk_span(first_span, {:name => :sidekiqtests, :type => :entry})

    assert_equal :'sidekiq-client', second_span[:n]
    assert_equal 'some_random_queue', second_span[:data][:'sidekiq-client'][:queue]
    assert_equal 'SidekiqJobOne', second_span[:data][:'sidekiq-client'][:job]
    assert_equal "false", second_span[:data][:'sidekiq-client'][:retry]
    assert_equal job['jid'], second_span[:data][:'sidekiq-client'][:job_id]
  end

  def assert_failure_trace_recorded
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    first_span = spans[1]
    second_span = spans[0]

    assert_equal first_span[:s], second_span[:p]
    validate_sdk_span(first_span, {:name => :sidekiqtests, :type => :entry})

    assert_equal :'sidekiq-client', second_span[:n]
    assert_equal true, second_span[:error]
    assert_equal false, second_span[:stack].nil?

    assert_equal 'some_random_queue', second_span[:data][:'sidekiq-client'][:queue]
    assert_equal 'SidekiqJobTwo', second_span[:data][:'sidekiq-client'][:job]
    assert_equal "false", second_span[:data][:'sidekiq-client'][:retry]
    assert_equal 'Fail to enqueue job', second_span[:data][:log][:message]
  end

  SidekiqMiddlewareException = Class.new do
    def call(*_args)
      raise 'Fail to enqueue job'
    end
  end

  def add_sidekiq_exception_middleware
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add SidekiqMiddlewareException
      end
    end
  end

  def remove_sidekiq_exception_middleware
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.remove SidekiqMiddlewareException
      end
    end
  end
end
