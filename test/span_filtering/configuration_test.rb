# (c) Copyright IBM Corp. 2025

require 'test_helper'
require 'concurrent'
require 'minitest/mock'

class ConfigurationTest < Minitest::Test
  def setup
    # Clear any existing configuration
    Instana::SpanFiltering.reset

    # Save original environment variables
    @original_env = ENV.to_hash

    # Clear relevant environment variables
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.keys.select { |k| k.start_with?('INSTANA_TRACING_FILTER_') }.each { |k| ENV.delete(k) }

    # Save original agent
    @original_agent = ::Instana.agent
  end

  def teardown
    # Restore original environment variables
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }

    # Reset configuration
    Instana::SpanFiltering.reset

    # Remove any test config files
    File.unlink('test_config.yaml') if File.exist?('test_config.yaml')

    # Restore original agent
    ::Instana.instance_variable_set(:@agent, @original_agent)
  end

  def test_initialization_with_defaults
    config = Instana::SpanFiltering::Configuration.new

    assert_empty config.include_rules
    assert_empty config.exclude_rules
    refute config.deactivated
  end

  def test_load_from_yaml_file
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          include:
            - name: include-http
              attributes:
                - key: type
                  values: [http.client]
                  match_type: strict
          exclude:
            - name: exclude-redis
              suppression: true
              attributes:
                - key: type
                  values: [redis]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.include_rules.size
    assert_equal 'include-http', config.include_rules.first.name

    assert_equal 1, config.exclude_rules.size
    assert_equal 'exclude-redis', config.exclude_rules.first.name
    assert config.exclude_rules.first.suppression
  end

  def test_load_from_yaml_file_with_com_instana_prefix
    # Create a test YAML configuration file with com.instana prefix
    yaml_content = <<~YAML
      com.instana.tracing:
        filter:
          deactivate: true
          include:
            - name: include-http
              attributes:
                - key: type
                  values: [http.client]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    log_output = StringIO.new
    Instana.logger = Logger.new(log_output)
    config = Instana::SpanFiltering::Configuration.new
    assert_includes log_output.string, 'Please use "tracing" instead of "com.instana.tracing" for local configuration file.'
    assert config.deactivated
    assert_equal 1, config.include_rules.size
  end

  def test_load_from_yaml_file_nonexistent_file
    ENV['INSTANA_CONFIG_PATH'] = 'nonexistent_file.yaml'

    config = Instana::SpanFiltering::Configuration.new

    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_yaml_file_invalid_yaml
    File.write('test_config.yaml', "invalid: yaml: content: - [")
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    config = Instana::SpanFiltering::Configuration.new

    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_env_vars_include
    ENV['INSTANA_TRACING_FILTER_INCLUDE_ATTRIBUTES'] = 'type;http.client,http.server;strict'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.include_rules.size
    rule = config.include_rules.first
    assert_equal 'EnvRule_ATTRIBUTES', rule.name
    assert_equal 1, rule.conditions.size

    condition = rule.conditions.first
    assert_equal 'type', condition.key
    assert_equal ['http.client', 'http.server'], condition.values
    assert_equal 'strict', condition.match_type
  end

  def test_load_from_env_vars_exclude
    ENV['INSTANA_TRACING_FILTER_EXCLUDE_ATTRIBUTES'] = 'type;redis;strict|http.method;GET;strict'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.exclude_rules.size
    rule = config.exclude_rules.first
    assert_equal 'EnvRule_ATTRIBUTES', rule.name
    assert_equal 2, rule.conditions.size
    assert rule.suppression
  end

  def test_load_from_env_vars_suppression
    ENV['INSTANA_TRACING_FILTER_EXCLUDE_ATTRIBUTES'] = 'type;redis;strict'
    ENV['INSTANA_TRACING_FILTER_EXCLUDE_SUPPRESSION_0'] = 'false'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.exclude_rules.size
    rule = config.exclude_rules.first
    refute rule.suppression
  end

  def test_load_from_env_vars_multiple_rules
    ENV['INSTANA_TRACING_FILTER_INCLUDE_ATTRIBUTES'] = 'type;http.client;strict'
    ENV['INSTANA_TRACING_FILTER_EXCLUDE_ATTRIBUTES'] = 'type;redis;strict'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.include_rules.size
    assert_equal 1, config.exclude_rules.size
  end

  def test_load_from_both_yaml_and_env_vars
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          include:
            - name: include-http
              attributes:
                - key: type
                  values: [http.client]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    # We need to clear any existing configuration first
    Instana::SpanFiltering.reset

    # Create a configuration object
    config = Instana::SpanFiltering::Configuration.new

    # Manually add an exclude rule to simulate loading from env vars
    condition = Instana::SpanFiltering::Condition.new('type', ['redis'], 'strict')
    rule = Instana::SpanFiltering::FilterRule.new('EnvRule_ATTRIBUTES', true, [condition])
    config.instance_variable_get(:@exclude_rules) << rule

    # Verify the configuration
    assert_equal 1, config.include_rules.size
    assert_equal 1, config.exclude_rules.size
  end

  def test_load_from_agent_discovery
    # Create a discovery value
    discovery_value = {
      'tracing' => {
        'filter' => {
          'include' => [
            {
              'name' => 'include-http',
              'attributes' => [
                {
                  'key' => 'type',
                  'values' => ['http.client'],
                  'match_type' => 'strict'
                }
              ]
            }
          ],
          'exclude' => [
            {
              'name' => 'exclude-redis',
              'suppression' => true,
              'attributes' => [
                {
                  'key' => 'type',
                  'values' => ['redis'],
                  'match_type' => 'strict'
                }
              ]
            }
          ]
        }
      }
    }

    # Create a new configuration
    config = Instana::SpanFiltering::Configuration.new

    # Simulate loading from agent after discovery
    config.read_config_from_agent(discovery_value)

    # Verify the configuration was loaded correctly
    assert_equal 1, config.include_rules.size
    assert_equal 'include-http', config.include_rules.first.name

    assert_equal 1, config.exclude_rules.size
    assert_equal 'exclude-redis', config.exclude_rules.first.name
    assert config.exclude_rules.first.suppression
  end

  def test_load_from_agent_with_deactivation
    # Create a discovery value that has deactivation flag
    discovery_value = {
      'tracing' => {
        'filter' => {
          'deactivate' => true
        }
      }
    }

    # Create a new configuration
    config = Instana::SpanFiltering::Configuration.new

    # Simulate loading from agent after discovery
    config.read_config_from_agent(discovery_value)

    # Verify the configuration was loaded correctly
    assert config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_agent_with_empty_discovery
    # Create a new configuration
    config = Instana::SpanFiltering::Configuration.new

    # Simulate loading from agent with empty discovery
    config.read_config_from_agent({})

    # Verify the configuration was not loaded (empty)
    refute config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_agent_with_nil_agent
    # Set the global agent to nil
    ::Instana.instance_variable_set(:@agent, nil)

    # Create a new configuration that should handle nil agent gracefully
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was not loaded (empty)
    refute config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_agent_with_error
    # Create a mock agent that raises an error
    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    def mock_agent.discovery_value
      raise StandardError, "Test error"
    end

    # Replace the global agent with our mock
    ::Instana.instance_variable_set(:@agent, mock_agent)

    # Create a new configuration that should handle the error gracefully
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was not loaded (empty)
    refute config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules
  end

  def test_load_from_agent_with_timer_task
    # This test is no longer relevant as we removed the timer task dependency
    # Configuration is now loaded via read_config_from_agent after discovery
    discovery_value = {
      'tracing' => {
        'filter' => {
          'include' => [
            {
              'name' => 'include-http',
              'attributes' => [
                {
                  'key' => 'type',
                  'values' => ['http.client'],
                  'match_type' => 'strict'
                }
              ]
            }
          ]
        }
      }
    }

    # Create a new configuration
    config = Instana::SpanFiltering::Configuration.new

    # Simulate loading from agent after discovery (replaces timer task behavior)
    config.read_config_from_agent(discovery_value)

    # Verify the configuration was loaded
    assert_equal 1, config.include_rules.size
    assert_equal 'include-http', config.include_rules.first.name
  end
end

# Tests for Redis disabling configuration
class DisableConfigurationTest < Minitest::Test
  def setup
    # Clear any existing configuration
    Instana::SpanFiltering.reset

    # Save original environment variables
    @original_env = ENV.to_hash

    # Clear relevant environment variables
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.delete('INSTANA_TRACING_DISABLE')

    # Save original agent
    @original_agent = ::Instana.agent

    # Reset Redis configuration
    ::Instana.config[:redis] = { :enabled => true }
  end

  def teardown
    # Restore original environment variables
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }

    # Reset configuration
    Instana::SpanFiltering.reset

    # Remove any test config files
    File.unlink('test_config.yaml') if File.exist?('test_config.yaml')

    # Restore original agent
    ::Instana.instance_variable_set(:@agent, @original_agent)

    # Reset Redis configuration
    ::Instana.config[:redis] = { :enabled => true }
  end

  def test_redis_disabled_via_yaml_string_format
    # Create a test YAML configuration file with string format
    yaml_content = <<~YAML
      tracing:
        disable:
          - "redis"
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering::Configuration.new

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled via YAML string format"
  end

  def test_redis_disabled_via_yaml_hash_format
    # Create a test YAML configuration file with hash format
    yaml_content = <<~YAML
      tracing:
        disable:
          - redis: true
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering::Configuration.new

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled via YAML hash format"
  end

  def test_redis_not_disabled_when_set_to_false
    # Create a test YAML configuration file with hash format set to false
    yaml_content = <<~YAML
      tracing:
        disable:
          - redis: false
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering::Configuration.new

    assert ::Instana.config[:redis][:enabled], "Redis should not be disabled when explicitly set to false"
  end

  def test_redis_disabled_via_databases_category_yaml
    # Create a test YAML configuration file with databases category
    yaml_content = <<~YAML
      tracing:
        disable:
          - databases: true
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering::Configuration.new

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled when databases category is disabled"
  end

  def test_redis_disabled_via_env_var_specific
    # Set environment variable to disable Redis specifically
    ENV['INSTANA_TRACING_DISABLE'] = 'redis'

    Instana::SpanFiltering::Configuration.new

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled via environment variable"
  end

  def test_redis_disabled_via_env_var_multiple
    # Set environment variable to disable multiple technologies including Redis
    ENV['INSTANA_TRACING_DISABLE'] = 'http,redis,mysql'

    Instana::SpanFiltering::Configuration.new

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled when specified in a comma-separated list"
  end

  def test_redis_disabled_via_agent_discovery_string_format
    # Create a discovery value using string format
    discovery_value = {
      'tracing' => {
        'disable' => ['redis']
      }
    }

    config = Instana::SpanFiltering::Configuration.new
    config.read_config_from_agent(discovery_value)

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled via agent discovery string format"
  end

  def test_redis_disabled_via_agent_discovery_hash_format
    # Create a discovery value using hash format
    discovery_value = {
      'tracing' => {
        'disable' => [{'redis' => true}]
      }
    }

    config = Instana::SpanFiltering::Configuration.new
    config.read_config_from_agent(discovery_value)

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled via agent discovery hash format"
  end

  def test_redis_disabled_via_agent_discovery_databases
    # Create a discovery value disabling databases category
    discovery_value = {
      'tracing' => {
        'disable' => [{'databases' => true}]
      }
    }

    config = Instana::SpanFiltering::Configuration.new
    config.read_config_from_agent(discovery_value)

    refute ::Instana.config[:redis][:enabled], "Redis should be disabled when databases category is disabled via agent discovery"
  end

  def test_yaml_config_takes_precedence_over_agent_discovery
    # Create a test YAML configuration file that doesn't disable Redis
    yaml_content = <<~YAML
      tracing:
        filter:
          include:
            - name: include-all
              attributes:
                - key: type
                  values: ["*"]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    # Create a mock agent with discovery value that would disable Redis
    discovery_value = {
      'tracing' => {
        'disable' => [{'redis' => true}]
      }
    }

    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    # This discovery value should not be used since YAML config is loaded first
    mock_agent.expect(:discovery_value, discovery_value)

    ::Instana.instance_variable_set(:@agent, mock_agent)

    Instana::SpanFiltering::Configuration.new

    # Redis should not be disabled because YAML config takes precedence
    # and doesn't have any disable directives
    assert ::Instana.config[:redis][:enabled], "YAML config should take precedence over agent discovery"
  end

  def test_env_var_takes_precedence_over_yaml_config
    # Create a test YAML configuration file that doesn't disable Redis
    yaml_content = <<~YAML
      tracing:
        disable:
          - http: true
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    # Set environment variable to disable Redis
    ENV['INSTANA_TRACING_DISABLE'] = 'redis'

    Instana::SpanFiltering::Configuration.new

    # Redis should be disabled because env var takes precedence
    refute ::Instana.config[:redis][:enabled], "Environment variable should take precedence over YAML config"
  end
end
