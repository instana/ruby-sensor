require 'test_helper'

class SidekiqServerTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:'sidekiq-worker'].is_a?(Hash)
    assert ::Instana.config[:'sidekiq-worker'].key?(:enabled)
    assert_equal true, ::Instana.config[:'sidekiq-worker'][:enabled]
  end

  def test_successful_worker_starts_new_trace
    clear_all!
    $sidekiq_mode = :server
    inject_instrumentation

    disable_redis_instrumentation
    ::Sidekiq.redis_pool.with do |redis|
      redis.sadd('queues'.freeze, 'important')
      redis.lpush(
        'queue:important',
        <<-JSON
        {
          "class":"SidekiqJobOne",
          "args":[1,2,3],
          "queue":"important",
          "jid":"123456789"
        }
        JSON
      )
    end
    enable_redis_instrumentation
    sleep 1

    assert_equal 1, ::Instana.processor.queue_count
    assert_successful_worker_trace(::Instana.processor.queued_traces.first)

    $sidekiq_mode = :client
  end

  def test_failed_worker_starts_new_trace
    clear_all!
    $sidekiq_mode = :server
    inject_instrumentation

    disable_redis_instrumentation
    ::Sidekiq.redis_pool.with do |redis|
      redis.sadd('queues'.freeze, 'important')
      redis.lpush(
        'queue:important',
        <<-JSON
        {
          "class":"SidekiqJobTwo",
          "args":[1,2,3],
          "queue":"important",
          "jid":"123456789"
        }
        JSON
      )
    end
    enable_redis_instrumentation

    sleep 1
    assert_equal 1, ::Instana.processor.queue_count
    assert_failed_worker_trace(::Instana.processor.queued_traces.first)

    $sidekiq_mode = :client
  end

  def test_successful_worker_continues_previous_trace
    clear_all!
    $sidekiq_mode = :server
    inject_instrumentation

    Instana.tracer.start_or_continue_trace(:sidekiqtests) do
      disable_redis_instrumentation
      ::Sidekiq::Client.push(
        'queue' => 'important',
        'class' => ::SidekiqJobOne,
        'args' => [1, 2, 3]
      )
      enable_redis_instrumentation
    end
    sleep 1
    assert_equal 2, ::Instana.processor.queue_count
    client_trace, worker_trace = differentiate_trace(
      Instana.processor.queued_traces.to_a
    )
    assert_client_trace(client_trace, ::SidekiqJobOne)
    assert_successful_worker_trace(worker_trace)

    # Worker trace and client trace are in the same trace
    assert_equal client_trace.spans.first['t'], worker_trace.spans.first['t']

    $sidekiq_mode = :client
  end

  def test_failed_worker_continues_previous_trace
    clear_all!
    $sidekiq_mode = :server
    inject_instrumentation

    Instana.tracer.start_or_continue_trace(:sidekiqtests) do
      disable_redis_instrumentation
      ::Sidekiq::Client.push(
        'queue' => 'important',
        'class' => ::SidekiqJobTwo,
        'args' => [1, 2, 3]
      )
      enable_redis_instrumentation
    end
    sleep 1
    assert_equal 2, ::Instana.processor.queue_count
    client_trace, worker_trace = differentiate_trace(
      Instana.processor.queued_traces.to_a
    )
    assert_client_trace(client_trace, ::SidekiqJobTwo)
    assert_failed_worker_trace(worker_trace)

    # Worker trace and client trace are in the same trace
    assert_equal client_trace.spans.first['t'], worker_trace.spans.first['t']

    $sidekiq_mode = :client
  end

  private

  def inject_instrumentation
    # Add the instrumentation again to ensure injection in server mode
    ::Sidekiq.configure_server do |cfg|
      cfg.server_middleware do |chain|
        chain.add ::Instana::Instrumentation::SidekiqWorker
      end
    end
  end

  def differentiate_trace(traces)
    trying_client = traces[0]
    trying_server = traces[1]

    try_successfully = trying_client.spans.any? do |span|
      span.name == :'sidekiq-client'
    end

    if try_successfully
      [trying_client, trying_server]
    else
      [trying_server, trying_client]
    end
  end

  def assert_successful_worker_trace(worker_trace)
    assert_equal 1, worker_trace.spans.length
    span = worker_trace.spans.first

    assert_equal :'sidekiq-worker', span[:n]

    assert_equal 'important', span[:data][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobOne', span[:data][:'sidekiq-worker'][:job]
    assert_equal false, span[:data][:'sidekiq-worker'][:job_id].nil?
  end

  def assert_failed_worker_trace(worker_trace)
    assert_equal 1, worker_trace.spans.length
    span = worker_trace.spans.first

    assert_equal :'sidekiq-worker', span[:n]

    assert_equal 'important', span[:data][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobTwo', span[:data][:'sidekiq-worker'][:job]
    assert_equal false, span[:data][:'sidekiq-worker'][:job_id].nil?

    assert_equal true, span[:data][:'sidekiq-worker'][:error]
    assert_equal 'Fail to execute the job', span[:data][:log][:message]
  end

  def assert_client_trace(client_trace, job)
    assert_equal 2, client_trace.spans.length
    first_span, second_span = client_trace.spans.to_a

    assert_equal :sdk, first_span[:n]
    assert_equal :sidekiqtests, first_span[:data][:sdk][:name]

    assert_equal first_span.id, second_span[:p]

    assert_equal :'sidekiq-client', second_span[:n]
    assert_equal 'important', second_span[:data][:'sidekiq-client'][:queue]
    assert_equal job.name, second_span[:data][:'sidekiq-client'][:job]
  end
end
