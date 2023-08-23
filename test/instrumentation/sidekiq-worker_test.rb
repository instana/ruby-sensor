# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'
require 'support/apps/sidekiq/boot'

class SidekiqServerTest < Minitest::Test
  def setup
    @framework_version = Gem::Specification.find_by_name('sidekiq').version
    @supported_framework_version = @framework_version < Gem::Version.new('5.3')
    @execute_test_if_framework_version_is_supported = lambda {
      unless @supported_framework_version
        skip "Skipping this test because sidekiq version #{@framework_version} is not yet supported!"
      end
    }
    @execute_test_only_if_framework_version_is_not_supported = lambda {
      if @supported_framework_version
        skip "Skipping this test because sidekiq version #{@framework_version} is already supported!"
      end
    }

    Sidekiq.configure_client do |config|
      config.redis = { url: ENV["REDIS_URL"] }
    end
  end

  def test_config_defaults
    @execute_test_if_framework_version_is_supported.call
    assert ::Instana.config[:'sidekiq-worker'].is_a?(Hash)
    assert ::Instana.config[:'sidekiq-worker'].key?(:enabled)
    assert_equal true, ::Instana.config[:'sidekiq-worker'][:enabled]

    activator = ::Instana::Activators::SidekiqServer.new
    assert_equal true, activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:'sidekiq-worker'][:enabled] = false

    activator = ::Instana::Activators::SidekiqServer.new
    assert_equal false, activator.can_instrument?
  end

  def test_no_sidekiq_tracing_if_unsupported_version_only_redis
    @execute_test_only_if_framework_version_is_not_supported.call
    clear_all!
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

    spans = Instana.processor.queued_spans
    assert spans
  end

  def test_successful_worker_starts_new_trace
    @execute_test_if_framework_version_is_supported.call
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

    spans = Instana.processor.queued_spans
    worker_span = find_spans_by_name(spans, :'sidekiq-worker').first
    assert_successful_worker_span(worker_span)

    $sidekiq_mode = :client
  end

  def test_failed_worker_starts_new_trace
    @execute_test_if_framework_version_is_supported.call
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

    spans = Instana.processor.queued_spans
    worker_span = find_spans_by_name(spans, :'sidekiq-worker').first
    assert_failed_worker_span(worker_span)

    $sidekiq_mode = :client
  end

  def test_successful_worker_continues_previous_trace
    @execute_test_if_framework_version_is_supported.call
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
    spans = Instana.processor.queued_spans

    sdk_span = find_spans_by_name(spans, :sidekiqtests).first
    validate_sdk_span(sdk_span)

    client_span = find_spans_by_name(spans, :'sidekiq-client').first
    assert_client_span(client_span, ::SidekiqJobOne)

    worker_span = find_spans_by_name(spans, :'sidekiq-worker').first
    assert_successful_worker_span(worker_span)

    # Worker trace and client trace are in the same trace
    assert_equal worker_span[:t], client_span[:t]
    assert_equal worker_span[:p], client_span[:s]

    $sidekiq_mode = :client
  end

  def test_failed_worker_continues_previous_trace
    @execute_test_if_framework_version_is_supported.call
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

    spans = Instana.processor.queued_spans

    sdk_span = find_spans_by_name(spans, :sidekiqtests).first
    validate_sdk_span(sdk_span)

    client_span = find_spans_by_name(spans, :'sidekiq-client').first
    assert_client_span(client_span, ::SidekiqJobTwo)

    worker_span = find_spans_by_name(spans, :'sidekiq-worker').first
    assert_failed_worker_span(worker_span)

    # Worker trace and client trace are in the same trace
    assert_equal worker_span[:t], client_span[:t]
    assert_equal worker_span[:p], client_span[:s]

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

  def assert_successful_worker_span(worker_span)
    assert_equal :'sidekiq-worker', worker_span[:n]

    assert_equal 'important', worker_span[:data][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobOne', worker_span[:data][:'sidekiq-worker'][:job]
    assert_equal false, worker_span[:data][:'sidekiq-worker'][:job_id].nil?
  end

  def assert_failed_worker_span(worker_span)
    assert_equal :'sidekiq-worker', worker_span[:n]

    assert_equal 'important', worker_span[:data][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobTwo', worker_span[:data][:'sidekiq-worker'][:job]
    assert_equal false, worker_span[:data][:'sidekiq-worker'][:job_id].nil?

    assert_equal true, worker_span[:data][:'sidekiq-worker'][:error]
    assert_equal 'Fail to execute the job', worker_span[:data][:log][:message]
  end

  def assert_client_span(client_span, job)
    assert_equal :'sidekiq-client', client_span[:n]
    assert_equal 'important', client_span[:data][:'sidekiq-client'][:queue]
    assert_equal job.name, client_span[:data][:'sidekiq-client'][:job]
  end
end
