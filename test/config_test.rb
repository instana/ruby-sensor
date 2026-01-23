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
end
