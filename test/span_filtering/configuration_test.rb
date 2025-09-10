# (c) Copyright IBM Corp. 2025

require 'test_helper'

class ConfigurationTest < Minitest::Test
  def setup
    # Clear any existing configuration
    Instana::SpanFiltering.reset

    # Save original environment variables
    @original_env = ENV.to_hash

    # Clear relevant environment variables
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.keys.select { |k| k.start_with?('INSTANA_TRACING_FILTER_') }.each { |k| ENV.delete(k) }
  end

  def teardown
    # Restore original environment variables
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }

    # Reset configuration
    Instana::SpanFiltering.reset

    # Remove any test config files
    File.unlink('test_config.yaml') if File.exist?('test_config.yaml')
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
    ENV['INSTANA_TRACING_FILTER_EXCLUDE_ATTRIBUTES'] = 'type;redis;strict'

    config = Instana::SpanFiltering::Configuration.new

    assert_equal 1, config.include_rules.size
    assert_equal 1, config.exclude_rules.size
  end
end
