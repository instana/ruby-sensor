# (c) Copyright IBM Corp. 2025

require 'test_helper'

class RedisDisableTest < Minitest::Test
  def setup
    @redis_url = if ENV.key?('REDIS_URL')
                   ENV['REDIS_URL']
                 else
                   "redis://localhost:6379"
                 end
    @redis_client = Redis.new(url: @redis_url)

    # Reset span filtering configuration before each test
    ::Instana::SpanFiltering.reset
    ::Instana::SpanFiltering.initialize

    # Reset Redis configuration
    ::Instana.config[:redis] = { :enabled => true }

    clear_all!
  end

  def teardown
    # Reset span filtering configuration after each test
    ::Instana::SpanFiltering.reset
    ::Instana::SpanFiltering.initialize

    # Reset Redis configuration
    ::Instana.config[:redis] = { :enabled => true }
  end

  def test_redis_disabled_by_configuration
    # Set Redis to be disabled via configuration
    ::Instana.config[:redis][:enabled] = false

    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  end

  def test_redis_disabled_via_databases_category
    # Create a mock configuration that disables the databases category
    config = ::Instana::SpanFiltering::Configuration.new

    # Simulate disabling databases category
    config.send(:update_instana_config_for_disabled_technology, 'databases')

    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  end

  def test_redis_disabled_via_yaml_config
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        disable:
          - redis
    YAML

    File.write('test_redis_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_redis_config.yaml'

    # Create a new configuration that should load from our YAML file
    ::Instana::SpanFiltering::Configuration.new

    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  ensure
    # Remove test config file
    File.unlink('test_redis_config.yaml') if File.exist?('test_redis_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_redis_disabled_via_env_var
    # Set environment variable to disable Redis
    ENV['INSTANA_TRACING_DISABLE'] = 'redis'

    # Create a new configuration that should load from our environment variable
    ::Instana::SpanFiltering::Configuration.new

    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  ensure
    ENV.delete('INSTANA_TRACING_DISABLE')
  end

  def test_redis_disabled_via_databases_env_var
    # Set environment variable to disable databases category
    ENV['INSTANA_TRACING_DISABLE'] = 'databases'

    # Create a new configuration that should load from our environment variable
    ::Instana::SpanFiltering::Configuration.new

    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that only the parent span is reported (Redis span is disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length
    assert_equal :sdk, spans[0][:n]
  ensure
    ENV.delete('INSTANA_TRACING_DISABLE')
  end

  def test_redis_not_disabled_by_default
    # Execute Redis operation
    Instana.tracer.in_span(:redis_test) do
      @redis_client.set('hello', 'world')
    end

    # Verify that both spans are reported (Redis span is not disabled)
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    first_span, second_span = spans.to_a.reverse
    assert_equal :sdk, first_span[:n]
    assert_equal :redis, second_span[:n]
  end

  private

  def clear_all!
    ::Instana.processor.clear!
    ::Instana.tracer.clear!
  end
end
