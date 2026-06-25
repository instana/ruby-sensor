# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'

class ConfigTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def test_that_config_exists
    refute_nil ::Instana.config
    assert_instance_of(::Instana::Config, ::Instana.config)
  end

  def test_that_it_has_defaults
    assert_equal '127.0.0.1', ::Instana.config[:agent_host]
    assert_equal 42699, ::Instana.config[:agent_port]

    assert ::Instana.config[:tracing][:enabled]
    assert ::Instana.config[:metrics][:enabled]

    ::Instana.config[:metrics].each do |k, v|
      next unless v.is_a? Hash
      assert_equal true, ::Instana.config[:metrics][k].key?(:enabled)
    end
  end

  def test_custom_agent_host
    subject = Instana::Config.new(logger: Logger.new('/dev/null'), agent_host: 'abc')
    assert_equal 'abc', subject[:agent_host]
  end

  def test_custom_agent_port
    subject = Instana::Config.new(logger: Logger.new('/dev/null'), agent_port: 'abc')
    assert_equal 'abc', subject[:agent_port]
  end

  def test_read_span_stack_config_from_env_with_both_values
    ENV['INSTANA_STACK_TRACE'] = 'all'
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '40'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 40, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE')
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_read_span_stack_config_from_env_with_error_level
    ENV['INSTANA_STACK_TRACE'] = 'error'
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '30'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE')
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_read_span_stack_config_from_env_with_none_level
    ENV['INSTANA_STACK_TRACE'] = 'none'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE')
  end

  def test_read_span_stack_config_from_env_with_only_stack_trace_length
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '20'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal "error", subject[:back_trace][:stack_trace_level]
    assert_equal 20, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_read_span_stack_config_from_env_with_no_env_vars
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal "error", subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  end

  def test_read_span_stack_config_from_env_converts_length_to_integer
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '25'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal 25, subject[:back_trace][:stack_trace_length]
    assert_instance_of Integer, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_read_span_stack_config_from_env_with_zero_length
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '0'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_span_stack_config_from_env

    assert_equal 0, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  # Tests for YAML configuration reading

  def test_read_span_stack_config_from_yaml_with_both_values
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: all
          stack-trace-length: 25
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 25, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_from_yaml_with_error_level
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: error
          stack-trace-length: 15
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 15, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_from_yaml_with_none_level
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: none
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_from_yaml_with_only_length
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace-length: 10
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 10, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_from_yaml_with_com_instana_tracing
    yaml_content = <<~YAML
      com.instana.tracing:
        global:
          stack-trace: all
          stack-trace-length: 20
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 20, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_yaml_missing_global_section
    yaml_content = <<~YAML
      tracing:
        filter:
          deactivate: false
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Should fall back to defaults
    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'default', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_env_takes_precedence_over_yaml
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: all
          stack-trace-length: 50
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'
    ENV['INSTANA_STACK_TRACE'] = 'none'
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '5'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Environment variables should take precedence
    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 5, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.delete('INSTANA_STACK_TRACE')
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_read_span_stack_config_invalid_yaml_falls_back_to_env
    File.write('test_stack_config.yaml', "invalid: yaml: content: - [")
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'
    ENV['INSTANA_STACK_TRACE'] = 'all'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Should fall back to env vars
    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.delete('INSTANA_STACK_TRACE')
  end

  # Tests for reading configuration from agent discovery

  def test_read_config_from_agent_with_stack_trace_config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 100
        }
      }
    }

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_config_from_agent(discovery)

    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 100, subject[:back_trace][:stack_trace_length]
    assert_equal 'agent', subject[:back_trace][:config_source]
  end

  def test_read_config_from_agent_with_only_stack_trace_level
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'none'
        }
      }
    }

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_config_from_agent(discovery)

    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'agent', subject[:back_trace][:config_source]
  end

  def test_read_config_from_agent_with_only_stack_trace_length
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace-length' => 75
        }
      }
    }

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_config_from_agent(discovery)

    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 75, subject[:back_trace][:stack_trace_length]
    assert_equal 'agent', subject[:back_trace][:config_source]
  end

  def test_read_config_from_agent_without_tracing_config
    discovery = {
      'pid' => 12345,
      'agentUuid' => 'test-uuid'
    }

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    original_config = subject[:back_trace].dup
    subject.read_config_from_agent(discovery)

    # Config should remain unchanged
    assert_equal original_config, subject[:back_trace]
  end

  def test_read_config_from_agent_with_empty_discovery
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    original_config = subject[:back_trace].dup
    subject.read_config_from_agent({})

    # Config should remain unchanged
    assert_equal original_config, subject[:back_trace]
  end

  def test_read_config_from_agent_with_nil_discovery
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    original_config = subject[:back_trace].dup
    subject.read_config_from_agent(nil)

    # Config should remain unchanged
    assert_equal original_config, subject[:back_trace]
  end

  # Tests for configuration priority: Env > YAML > Agent > Default

  def test_priority_env_over_yaml
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: all
          stack-trace-length: 50
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'
    ENV['INSTANA_STACK_TRACE'] = 'none'
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '10'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Environment variables should take precedence over YAML
    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 10, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.delete('INSTANA_STACK_TRACE')
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_priority_yaml_over_agent_when_no_env
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: none
          stack-trace-length: 10
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Try to override with agent config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 100
        }
      }
    }
    subject.read_config_from_agent(discovery)

    # YAML should take precedence over agent (when no env vars)
    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 10, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_priority_env_over_agent
    ENV['INSTANA_STACK_TRACE'] = 'error'
    ENV['INSTANA_STACK_TRACE_LENGTH'] = '20'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Try to override with agent config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 100
        }
      }
    }
    subject.read_config_from_agent(discovery)

    # Env should take precedence
    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 20, subject[:back_trace][:stack_trace_length]
    assert_equal 'env', subject[:back_trace][:config_source]
  ensure
    ENV.delete('INSTANA_STACK_TRACE')
    ENV.delete('INSTANA_STACK_TRACE_LENGTH')
  end

  def test_priority_agent_over_default
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Verify default config
    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'default', subject[:back_trace][:config_source]

    # Override with agent config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 50
        }
      }
    }
    subject.read_config_from_agent(discovery)

    # Agent should override default
    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 50, subject[:back_trace][:stack_trace_length]
    assert_equal 'agent', subject[:back_trace][:config_source]
  end

  def test_should_read_from_agent_returns_true_for_default_config
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    assert subject.send(:should_read_from_agent?, :back_trace)
  end

  def test_should_read_from_agent_returns_false_for_yaml_config
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: all
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    refute subject.send(:should_read_from_agent?, :back_trace)
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_should_read_from_agent_returns_false_for_env_config
    ENV['INSTANA_STACK_TRACE'] = 'all'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    refute subject.send(:should_read_from_agent?, :back_trace)
  ensure
    ENV.delete('INSTANA_STACK_TRACE')
  end

  # Tests for technology-specific stack trace configuration

  def test_read_span_stack_config_from_yaml_with_technology_specific_config
    yaml_content = <<~YAML
      com.instana.tracing:
        global:
          stack-trace: error
          stack-trace-length: 25

        kafka:
          stack-trace: all

        redis:
          stack-trace: all
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Check global config
    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 25, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]

    # Check technology-specific configs
    assert_equal 'all', subject[:back_trace_technologies][:kafka][:stack_trace_level]
    assert_equal 'all', subject[:back_trace_technologies][:redis][:stack_trace_level]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_span_stack_config_from_yaml_with_technology_specific_length
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: error
          stack-trace-length: 30

        kafka:
          stack-trace: all
          stack-trace-length: 50

        redis:
          stack-trace-length: 10
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Check kafka config
    kafka_config = subject[:back_trace_technologies][:kafka]
    assert_equal 'all', kafka_config[:stack_trace_level]
    assert_equal 50, kafka_config[:stack_trace_length]

    # Check redis config (only length specified)
    redis_config = subject[:back_trace_technologies][:redis]
    assert_nil redis_config[:stack_trace_level]
    assert_equal 10, redis_config[:stack_trace_length]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_get_stack_trace_config_for_technology
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: error
          stack-trace-length: 30

        kafka:
          stack-trace: all
          stack-trace-length: 50

        redis:
          stack-trace: all
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Test kafka - should use technology-specific config
    kafka_config = subject.get_stack_trace_config(:kafka)
    assert_equal 'all', kafka_config[:stack_trace_level]
    assert_equal 50, kafka_config[:stack_trace_length]

    # Test redis - should use technology-specific level, global length
    redis_config = subject.get_stack_trace_config(:redis)
    assert_equal 'all', redis_config[:stack_trace_level]
    assert_equal 30, redis_config[:stack_trace_length]

    # Test excon - should fall back to global config
    excon_config = subject.get_stack_trace_config(:excon)
    assert_equal 'error', excon_config[:stack_trace_level]
    assert_equal 30, excon_config[:stack_trace_length]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end

  def test_read_config_from_agent_with_technology_specific_config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'error',
          'stack-trace-length' => 30
        },
        'kafka' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 100
        },
        'redis' => {
          'stack-trace' => 'all'
        }
      }
    }

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    subject.read_config_from_agent(discovery)

    # Check global config
    assert_equal 'error', subject[:back_trace][:stack_trace_level]
    assert_equal 30, subject[:back_trace][:stack_trace_length]
    assert_equal 'agent', subject[:back_trace][:config_source]

    # Check technology-specific configs
    kafka_config = subject[:back_trace_technologies][:kafka]
    assert_equal 'all', kafka_config[:stack_trace_level]
    assert_equal 100, kafka_config[:stack_trace_length]

    redis_config = subject[:back_trace_technologies][:redis]
    assert_equal 'all', redis_config[:stack_trace_level]
    assert_nil redis_config[:stack_trace_length]
  end

  def test_yaml_technology_config_not_overridden_by_agent_when_no_env
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: none
          stack-trace-length: 10

        kafka:
          stack-trace: error
          stack-trace-length: 20
    YAML

    File.write('test_stack_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_stack_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    # Try to override with agent config
    discovery = {
      'tracing' => {
        'global' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 100
        },
        'kafka' => {
          'stack-trace' => 'all',
          'stack-trace-length' => 200
        }
      }
    }
    subject.read_config_from_agent(discovery)

    # YAML should take precedence for both global and technology-specific (when no env vars)
    assert_equal 'none', subject[:back_trace][:stack_trace_level]
    assert_equal 10, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]

    kafka_config = subject[:back_trace_technologies][:kafka]
    assert_equal 'error', kafka_config[:stack_trace_level]
    assert_equal 20, kafka_config[:stack_trace_length]
  ensure
    File.unlink('test_stack_config.yaml') if File.exist?('test_stack_config.yaml')
    ENV.delete('INSTANA_CONFIG_PATH')
  end
end

# ============================================================================
# OTLP configuration tests
# ============================================================================

class OtlpConfigTest < Minitest::Test
  OTLP_ENV_VARS = %w[
    INSTANA_TRACING_OTLP_ENABLED
    OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
    OTEL_EXPORTER_OTLP_ENDPOINT
    OTEL_EXPORTER_OTLP_TIMEOUT
    OTEL_EXPORTER_OTLP_COMPRESSION
    OTEL_EXPORTER_OTLP_HEADERS
    OTEL_EXPORTER_OTLP_CERTIFICATE
    OTEL_EXPORTER_OTLP_CLIENT_KEY
    OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE
    INSTANA_CONFIG_PATH
  ].freeze

  def setup
    OTLP_ENV_VARS.each { |k| ENV.delete(k) }
  end

  def teardown
    OTLP_ENV_VARS.each { |k| ENV.delete(k) }
    File.unlink('test_otlp_config.yaml') if File.exist?('test_otlp_config.yaml')
  end

  # ── defaults ───────────────────────────────────────────────────────────────

  def test_otlp_defaults_when_no_env_or_yaml
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    otlp = subject[:otlp]
    refute_nil otlp, 'config[:otlp] should always be populated'
    assert_equal false, otlp[:enabled]
    assert_equal 'http://localhost:4318/v1/traces', otlp[:endpoint]
    assert_equal 10_000, otlp[:timeout]
    assert_nil otlp[:compression]
    assert_equal({}, otlp[:headers])
    assert_nil otlp[:certificate]
    assert_nil otlp[:client_key]
    assert_nil otlp[:client_certificate]
    assert_equal 'default', otlp[:config_source]
  end

  # ── INSTANA_TRACING_OTLP_ENABLED truthy variants ──────────────────────────

  def test_enable_flag_true_string
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'true'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true,  subject[:otlp][:enabled]
    assert_equal 'env', subject[:otlp][:config_source]
  end

  def test_enable_flag_one_string
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = '1'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true, subject[:otlp][:enabled]
  end

  def test_enable_flag_yes_string
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'yes'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true, subject[:otlp][:enabled]
  end

  def test_enable_flag_yes_case_insensitive
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'YES'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true, subject[:otlp][:enabled]
  end

  def test_enable_flag_false_leaves_disabled
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'false'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal false, subject[:otlp][:enabled]
    assert_equal 'env', subject[:otlp][:config_source]
  end

  # ── endpoint precedence ────────────────────────────────────────────────────

  def test_traces_endpoint_takes_precedence_over_base_endpoint
    ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://traces.example.com/v1/traces'
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT']        = 'http://base.example.com'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'http://traces.example.com/v1/traces', subject[:otlp][:endpoint]
  end

  def test_base_endpoint_used_when_no_traces_endpoint
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://base.example.com'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'http://base.example.com', subject[:otlp][:endpoint]
  end

  # ── timeout ────────────────────────────────────────────────────────────────

  def test_timeout_stored_as_integer_milliseconds
    ENV['OTEL_EXPORTER_OTLP_TIMEOUT'] = '30000'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 30_000, subject[:otlp][:timeout]
    assert_instance_of Integer, subject[:otlp][:timeout]
  end

  # ── compression ───────────────────────────────────────────────────────────

  def test_compression_from_env
    ENV['OTEL_EXPORTER_OTLP_COMPRESSION'] = 'gzip'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal 'gzip', subject[:otlp][:compression]
  end

  # ── headers ───────────────────────────────────────────────────────────────

  def test_headers_parsed_from_env_into_hash
    ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'api-key=secret,x-tenant=tenant1'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal({ 'api-key' => 'secret', 'x-tenant' => 'tenant1' }, subject[:otlp][:headers])
  end

  def test_single_header_parsed_correctly
    ENV['OTEL_EXPORTER_OTLP_HEADERS'] = 'authorization=Bearer token123'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal({ 'authorization' => 'Bearer token123' }, subject[:otlp][:headers])
  end

  # ── TLS fields ────────────────────────────────────────────────────────────

  def test_tls_fields_from_env
    ENV['OTEL_EXPORTER_OTLP_CERTIFICATE']        = '/etc/certs/ca.pem'
    ENV['OTEL_EXPORTER_OTLP_CLIENT_KEY']         = '/etc/certs/client.key'
    ENV['OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE'] = '/etc/certs/client.crt'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal '/etc/certs/ca.pem',     subject[:otlp][:certificate]
    assert_equal '/etc/certs/client.key', subject[:otlp][:client_key]
    assert_equal '/etc/certs/client.crt', subject[:otlp][:client_certificate]
  end

  # ── YAML configuration ────────────────────────────────────────────────────

  def test_yaml_populates_otlp_config
    yaml_content = <<~YAML
      tracing:
        otlp:
          enabled: true
          endpoint: "http://otlp.example.com/v1/traces"
          timeout: 5000
          compression: gzip
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_otlp_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true, subject[:otlp][:enabled]
    assert_equal 'http://otlp.example.com/v1/traces', subject[:otlp][:endpoint]
    assert_equal 5000,                                  subject[:otlp][:timeout]
    assert_equal 'gzip',                                subject[:otlp][:compression]
    assert_equal 'yaml',                                subject[:otlp][:config_source]
  end

  def test_yaml_headers_as_hash
    yaml_content = <<~YAML
      tracing:
        otlp:
          enabled: true
          headers:
            x-api-key: mysecret
            x-tenant: acme
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_otlp_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal({ 'x-api-key' => 'mysecret', 'x-tenant' => 'acme' }, subject[:otlp][:headers])
  end

  def test_yaml_takes_precedence_over_env
    yaml_content = <<~YAML
      tracing:
        otlp:
          enabled: true
          endpoint: "http://from-yaml.example.com/v1/traces"
          timeout: 5000
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH']                 = 'test_otlp_config.yaml'
    ENV['INSTANA_TRACING_OTLP_ENABLED']        = 'false'
    ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://from-env.example.com/v1/traces'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal true, subject[:otlp][:enabled]
    assert_equal 'http://from-yaml.example.com/v1/traces', subject[:otlp][:endpoint]
    assert_equal 'yaml', subject[:otlp][:config_source]
  end

  def test_yaml_without_otlp_section_leaves_defaults
    yaml_content = <<~YAML
      tracing:
        global:
          stack-trace: error
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_otlp_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    assert_equal false,     subject[:otlp][:enabled]
    assert_equal 'default', subject[:otlp][:config_source]
  end

  # ── agent discovery ───────────────────────────────────────────────────────

  def test_agent_discovery_sets_otlp_config_when_source_is_default
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    assert_equal 'default', subject[:otlp][:config_source]

    discovery = {
      'tracing' => {
        'otlp' => {
          'enabled' => 'true',
          'endpoint' => 'http://agent.example.com/v1/traces',
          'timeout' => 8000
        }
      }
    }
    subject.read_config_from_agent(discovery)

    assert_equal true, subject[:otlp][:enabled]
    assert_equal 'http://agent.example.com/v1/traces', subject[:otlp][:endpoint]
    assert_equal 8000,                                    subject[:otlp][:timeout]
    assert_equal 'agent',                                 subject[:otlp][:config_source]
  end

  def test_agent_discovery_does_not_override_env_config
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'true'
    ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] = 'http://from-env.example.com/v1/traces'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    assert_equal 'env', subject[:otlp][:config_source]

    discovery = {
      'tracing' => {
        'otlp' => {
          'enabled' => 'false',
          'endpoint' => 'http://agent.example.com/v1/traces'
        }
      }
    }
    subject.read_config_from_agent(discovery)

    # env values must be preserved
    assert_equal true, subject[:otlp][:enabled]
    assert_equal 'http://from-env.example.com/v1/traces', subject[:otlp][:endpoint]
    assert_equal 'env', subject[:otlp][:config_source]
  end

  def test_agent_discovery_does_not_override_yaml_config
    yaml_content = <<~YAML
      tracing:
        otlp:
          enabled: true
          endpoint: "http://from-yaml.example.com/v1/traces"
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_otlp_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    assert_equal 'yaml', subject[:otlp][:config_source]

    discovery = {
      'tracing' => {
        'otlp' => {
          'enabled' => 'false',
          'endpoint' => 'http://agent.example.com/v1/traces'
        }
      }
    }
    subject.read_config_from_agent(discovery)

    assert_equal true, subject[:otlp][:enabled]
    assert_equal 'http://from-yaml.example.com/v1/traces', subject[:otlp][:endpoint]
    assert_equal 'yaml', subject[:otlp][:config_source]
  end

  def test_agent_discovery_without_otlp_key_is_ignored
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))

    discovery = { 'tracing' => { 'global' => { 'stack-trace' => 'all' } } }
    subject.read_config_from_agent(discovery)

    assert_equal false,     subject[:otlp][:enabled]
    assert_equal 'default', subject[:otlp][:config_source]
  end

  # ── should_read_from_agent? guard ────────────────────────────────────────

  def test_should_read_from_agent_returns_true_for_default_otlp
    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    assert subject.send(:should_read_from_agent?, :otlp)
  end

  def test_should_read_from_agent_returns_false_after_env_config
    ENV['INSTANA_TRACING_OTLP_ENABLED'] = 'true'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    refute subject.send(:should_read_from_agent?, :otlp)
  end

  def test_should_read_from_agent_returns_false_after_yaml_config
    yaml_content = <<~YAML
      tracing:
        otlp:
          enabled: true
    YAML

    File.write('test_otlp_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_otlp_config.yaml'

    subject = Instana::Config.new(logger: Logger.new('/dev/null'))
    refute subject.send(:should_read_from_agent?, :otlp)
  end
end
