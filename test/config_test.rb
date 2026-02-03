# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'

class ConfigTest < Minitest::Test
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
    assert_equal 'default', subject[:back_trace][:config_source]
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

  def test_read_span_stack_config_yaml_takes_precedence_over_env
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

    # YAML should take precedence
    assert_equal 'all', subject[:back_trace][:stack_trace_level]
    assert_equal 50, subject[:back_trace][:stack_trace_length]
    assert_equal 'yaml', subject[:back_trace][:config_source]
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

  # Tests for configuration priority: YAML > Env > Agent > Default

  def test_priority_yaml_over_agent
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

    # YAML should take precedence
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

  def test_yaml_technology_config_not_overridden_by_agent
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

    # YAML should take precedence for both global and technology-specific
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
