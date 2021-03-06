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
end
