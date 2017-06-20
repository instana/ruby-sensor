require 'test_helper'

class ConfigTest < Minitest::Test
  def test_that_config_exists
    refute_nil ::Instana.config
    assert_instance_of(::Instana::Config, ::Instana.config)
  end

  def test_that_it_has_defaults
    assert_equal '127.0.0.1', ::Instana.config[:agent_host]
    assert_equal 42699, ::Instana.config[:agent_port]

    assert ::Instana.config[:enabled]
    assert ::Instana.config[:tracing][:enabled]
    assert ::Instana.config[:metrics][:enabled]

    ::Instana.config[:metrics].each do |k, v|
      assert_equal true, ::Instana.config[:metrics][k].key?(:enabled)
    end
  end

  def test_that_global_affects_children
    # Disabling the gem should explicitly disable
    # metrics and tracing flags
    ::Instana.config[:enabled] = false

    assert_equal false, ::Instana.config[:tracing][:enabled]
    assert_equal false, ::Instana.config[:metrics][:enabled]

    # Enabling the gem should explicitly enable
    # metrics and tracing flags
    ::Instana.config[:enabled] = true

    assert_equal ::Instana.config[:tracing][:enabled]
    assert_equal ::Instana.config[:metrics][:enabled]
  end
end
