require 'test_helper'

class ConfigTest < Minitest::Test
  def test_that_config_exists
    refute_nil ::Instana.config
    assert_instance_of(::Instana::Config, ::Instana.config)
  end

  def test_that_it_has_defaults
    assert_equal '127.0.0.1', ::Instana.config[:agent_host]
    assert_equal 42699, ::Instana.config[:agent_port]
    assert_equal true, ::Instana.config[:metrics].key?(:gc)
    assert_equal true, ::Instana.config[:metrics].key?(:heap)
    assert_equal true, ::Instana.config[:metrics].key?(:memory)
    assert_equal true, ::Instana.config[:metrics].key?(:thread)
  end
end
