require 'test_helper'

class AgentTest < Minitest::Test
  def test_agent_host_detection
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, url)
    assert_equal true, ::Instana.agent.host_agent_ready?
  end

  def test_successful_discovery
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/"
    docker_url = "http://#{::Instana.agent.instance_variable_get(:@default_gateway)}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, url)
    stub_request(:get, docker_url)
    discovered = ::Instana.agent.run_discovery

    assert discovered.is_a?(Hash)
    assert_equal "127.0.0.1", discovered[:agent_host]
    assert_equal 42699, discovered[:agent_port]
  end

  def test_failed_discovery
    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/"
    docker_url = "http://#{::Instana.agent.instance_variable_get(:@default_gateway)}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, url).to_raise(Errno::ECONNREFUSED)
    stub_request(:get, docker_url).to_raise(Errno::ECONNREFUSED)
    discovered = ::Instana.agent.run_discovery

    assert_equal nil, discovered
  end

  def test_no_host_agent
    localhost_url = "http://#{::Instana::Agent::LOCALHOST}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, localhost_url).to_raise(Errno::ECONNREFUSED)
    docker_url = "http://#{::Instana.agent.instance_variable_get(:@default_gateway)}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, docker_url).to_timeout
    assert_equal false, ::Instana.agent.host_agent_ready?
  end

  def test_announce_sensor
    # Fake discovery values
    discovery = {}
    discovery[:agent_host] = ::Instana.config[:agent_host]
    discovery[:agent_port] = ::Instana.config[:agent_port]
    ::Instana.agent.instance_variable_set(:@discovered, discovery)

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    json = { 'pid' => Process.pid, 'agentUuid' => 'abc' }.to_json
    stub_request(:put, url).to_return(:body => json, :status => 200)

    assert_equal true, ::Instana.agent.announce_sensor
  end

  def test_failed_announce_sensor
    # Fake discovery values
    discovery = {}
    discovery[:agent_host] = ::Instana.config[:agent_host]
    discovery[:agent_port] = ::Instana.config[:agent_port]
    ::Instana.agent.instance_variable_set(:@discovered, discovery)

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    stub_request(:put, url).to_raise(Errno::ECONNREFUSED)

    assert_equal false, ::Instana.agent.announce_sensor
  end

  def test_entity_data_report
    # Fake discovery values
    discovery = {}
    discovery[:agent_host] = ::Instana.config[:agent_host]
    discovery[:agent_port] = ::Instana.config[:agent_port]
    ::Instana.agent.instance_variable_set(:@discovered, discovery)

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    json = { 'pid' => Process.pid, 'agentUuid' => 'abc' }.to_json
    stub_request(:put, url).to_return(:body => json, :status => 200)
    ::Instana.agent.announce_sensor

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.#{Process.pid}"
    stub_request(:post, url)

    payload = { :test => 'true' }
    assert_equal true, ::Instana.agent.report_entity_data(payload)
  end

  def test_failed_entity_data_report
    # Fake discovery values
    discovery = {}
    discovery[:agent_host] = ::Instana.config[:agent_host]
    discovery[:agent_port] = ::Instana.config[:agent_port]
    ::Instana.agent.instance_variable_set(:@discovered, discovery)

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.discovery"
    json = { 'pid' => Process.pid, 'agentUuid' => 'abc' }.to_json
    stub_request(:put, url).to_return(:body => json, :status => 200)

    ::Instana.agent.announce_sensor

    url = "http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/com.instana.plugin.ruby.#{Process.pid}"
    stub_request(:post, url).to_raise(Errno::ECONNREFUSED)

    payload = { :test => 'true' }
    assert_equal false, ::Instana.agent.report_entity_data(payload)
  end

  def test_agent_timeout
    # Fake discovery values
    discovery = {}
    discovery[:agent_host] = ::Instana.config[:agent_host]
    discovery[:agent_port] = ::Instana.config[:agent_port]
    ::Instana.agent.instance_variable_set(:@discovered, discovery)

    localhost_url = "http://#{::Instana::Agent::LOCALHOST}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, localhost_url).to_timeout
    docker_url = "http://#{::Instana.agent.instance_variable_get(:@default_gateway)}:#{::Instana.config[:agent_port]}/"
    stub_request(:get, docker_url).to_timeout
    assert_equal false, ::Instana.agent.host_agent_ready?
  end
end
