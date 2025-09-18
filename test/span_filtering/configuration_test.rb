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

    config = Instana::SpanFiltering::Configuration.new

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
    # Create a mock agent with discovery value
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

    # Create a mock agent
    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    mock_agent.expect(:discovery_value, discovery_value)

    # Replace the global agent with our mock
    ::Instana.instance_variable_set(:@agent, mock_agent)

    # Create a new configuration that should load from our mock agent
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was loaded correctly
    assert_equal 1, config.include_rules.size
    assert_equal 'include-http', config.include_rules.first.name

    assert_equal 1, config.exclude_rules.size
    assert_equal 'exclude-redis', config.exclude_rules.first.name
    assert config.exclude_rules.first.suppression

    mock_agent.verify
  end

  def test_load_from_agent_with_deactivation
    # Create a mock agent with discovery value that has deactivation flag
    discovery_value = {
      'tracing' => {
        'filter' => {
          'deactivate' => true
        }
      }
    }

    # Create a mock agent
    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    mock_agent.expect(:discovery_value, discovery_value)

    # Replace the global agent with our mock
    ::Instana.instance_variable_set(:@agent, mock_agent)

    # Create a new configuration that should load from our mock agent
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was loaded correctly
    assert config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules

    mock_agent.verify
  end

  def test_load_from_agent_with_empty_discovery
    # Create a mock agent with empty discovery value
    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    mock_agent.expect(:discovery_value, {})

    # Replace the global agent with our mock
    ::Instana.instance_variable_set(:@agent, mock_agent)

    # Create a new configuration that should try to load from our mock agent
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was not loaded (empty)
    refute config.deactivated
    assert_empty config.include_rules
    assert_empty config.exclude_rules

    mock_agent.verify
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
    # Save original INSTANA_TEST value
    original_test_env = ENV['INSTANA_TEST']
    ENV.delete('INSTANA_TEST') # Temporarily remove INSTANA_TEST to allow timer task creation

    # Mock the Concurrent::TimerTask class
    original_timer_task = Concurrent::TimerTask
    Concurrent.send(:remove_const, :TimerTask)

    # Create a custom timer task class that immediately executes the block
    Concurrent.const_set(:TimerTask, Class.new do
      def initialize(*args, &block)
        @block = block
        @running = false
        @args = args
      end

      def execute
        @running = true
        # Immediately execute the block when execute is called
        @block.call
        true
      end

      def shutdown
        @running = false
      end

      def running?
        @running
      end
    end)

    # Create a mock agent with nil discovery initially, then with real discovery later
    mock_agent = Minitest::Mock.new
    mock_agent.expect(:delegate, mock_agent)
    mock_agent.expect(:discovery_value, nil)

    # We need to set up the mock to return real discovery value on second call
    # This will be called by the timer task
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

    # Set up the mock to return real discovery value on second call
    mock_agent.expect(:delegate, mock_agent)
    mock_agent.expect(:discovery_value, discovery_value)

    # Replace the global agent with our mock
    ::Instana.instance_variable_set(:@agent, mock_agent)

    # Create a new configuration that should set up a timer task
    config = Instana::SpanFiltering::Configuration.new

    # Verify the configuration was loaded by the timer task
    assert_equal 1, config.include_rules.size
    assert_equal 'include-http', config.include_rules.first.name

    mock_agent.verify
  ensure
    # Restore the original TimerTask class
    if Concurrent.const_defined?(:TimerTask)
      Concurrent.send(:remove_const, :TimerTask)
      Concurrent.const_set(:TimerTask, original_timer_task)
    end

    # Restore original INSTANA_TEST value
    if original_test_env
      ENV['INSTANA_TEST'] = original_test_env
    else
      ENV.delete('INSTANA_TEST')
    end
  end
end
