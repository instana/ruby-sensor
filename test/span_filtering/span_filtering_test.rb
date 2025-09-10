# (c) Copyright IBM Corp. 2025

require 'test_helper'

class SpanFilteringTest < Minitest::Test
  def setup
    # Clear any existing configuration
    Instana::SpanFiltering.reset

    # Save original environment variables
    @original_env = ENV.to_hash

    # Clear relevant environment variables
    ENV.delete('INSTANA_CONFIG_PATH')
    ENV.keys.select { |k| k.start_with?('INSTANA_TRACING_FILTER_') }.each { |k| ENV.delete(k) }

    # Initialize with test configuration
    Instana::SpanFiltering.initialize

    @http_span = {
      'n' => 'http.client',
      'k' => 1,
      'data' => {
        'http' => {
          'url' => 'https://example.com/api',
          'method' => 'GET',
          'status' => 200
        }
      }
    }

    @redis_span = {
      'n' => 'redis',
      'k' => 3,
      'data' => {
        'redis' => {
          'command' => 'GET',
          'key' => 'user:123'
        }
      }
    }
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

  def test_initialization
    assert_instance_of Instana::SpanFiltering::Configuration, Instana::SpanFiltering.configuration
  end

  def test_deactivated_when_no_configuration
    Instana::SpanFiltering.reset
    refute Instana::SpanFiltering.deactivated?
  end

  def test_deactivated_when_explicitly_set
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          deactivate: true
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    assert Instana::SpanFiltering.deactivated?
  end

  def test_filter_span_when_deactivated
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          deactivate: true
          exclude:
            - name: exclude-all
              attributes:
                - key: type
                  values: ["*"]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    assert_nil Instana::SpanFiltering.filter_span(@http_span)
  end

  def test_filter_span_with_include_rule_match
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
            - name: exclude-all
              attributes:
                - key: type
                  values: ["*"]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    # HTTP span should be included (not filtered)
    assert_nil Instana::SpanFiltering.filter_span(@http_span)

    # Redis span should be excluded (filtered)
    result = Instana::SpanFiltering.filter_span(@redis_span)
    assert_instance_of Hash, result
    assert result[:filtered]
  end

  def test_filter_span_with_exclude_rule_match
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
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

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    # HTTP span should not be filtered
    assert_nil Instana::SpanFiltering.filter_span(@http_span)

    # Redis span should be filtered with suppression
    result = Instana::SpanFiltering.filter_span(@redis_span)
    assert_instance_of Hash, result
    assert result[:filtered]
    assert result[:suppression]
  end

  def test_filter_span_with_exclude_rule_no_suppression
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          exclude:
            - name: exclude-redis
              suppression: false
              attributes:
                - key: type
                  values: [redis]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    # Redis span should be filtered without suppression
    result = Instana::SpanFiltering.filter_span(@redis_span)
    assert_instance_of Hash, result
    assert result[:filtered]
    refute result[:suppression]
  end

  def test_filter_span_with_no_rules_match
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          exclude:
            - name: exclude-mysql
              attributes:
                - key: type
                  values: [mysql]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.reset
    Instana::SpanFiltering.initialize

    # Both spans should not be filtered
    assert_nil Instana::SpanFiltering.filter_span(@http_span)
    assert_nil Instana::SpanFiltering.filter_span(@redis_span)
  end

  def test_reset
    # Create a test YAML configuration file
    yaml_content = <<~YAML
      tracing:
        filter:
          exclude:
            - name: exclude-redis
              attributes:
                - key: type
                  values: [redis]
                  match_type: strict
    YAML

    File.write('test_config.yaml', yaml_content)
    ENV['INSTANA_CONFIG_PATH'] = 'test_config.yaml'

    Instana::SpanFiltering.initialize
    assert_instance_of Instana::SpanFiltering::Configuration, Instana::SpanFiltering.configuration

    Instana::SpanFiltering.reset
    assert_nil Instana::SpanFiltering.instance_variable_get(:@configuration)
  end
end
