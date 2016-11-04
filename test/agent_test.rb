require 'test_helper'

class AgentTest < Minitest::Test
  def test_agent_host_detection
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, url)
    assert_equal true, ::Instana.agent.host_agent_ready?
  end

  def test_no_host_agent
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, url).to_raise(Errno::ECONNREFUSED)
    assert_equal false, ::Instana.agent.host_agent_ready?
  end

  def test_announce_sensor
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    stub_request(:put, url)

    assert_equal true, ::Instana.agent.announce_sensor
  end

  def test_failed_announce_sensor
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    stub_request(:put, url).to_raise(Errno::ECONNREFUSED)

    assert_equal false, ::Instana.agent.announce_sensor
  end

  def test_entity_data_report
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.#{Process.pid}"
    stub_request(:post, url)

    payload = { :test => 'true' }
    assert_equal true, ::Instana.agent.report_entity_data(payload)
  end

  def test_failed_entity_data_report
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.#{Process.pid}"
    stub_request(:post, url).to_raise(Errno::ECONNREFUSED)

    payload = { :test => 'true' }
    assert_equal false, ::Instana.agent.report_entity_data(payload)
  end

end
