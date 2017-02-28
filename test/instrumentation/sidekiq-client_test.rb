require 'test_helper'

class SidekiqClientTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:sidekiq_client].is_a?(Hash)
    assert ::Instana.config[:sidekiq_client].key?(:enabled)
    assert_equal true, ::Instana.config[:sidekiq_client][:enabled]
  end

  def test_enqueue
    clear_all!

    Sidekiq::Client.push('queue' => 'important', 'class' => ::JobYellow, 'args' => [1, 2, 3], 'retry' => false)

  end
end
