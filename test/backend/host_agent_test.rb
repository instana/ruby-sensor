# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentTest < Minitest::Test
  def test_spawn_background_thread
    ENV['INSTANA_TEST'] = nil
    ::Instana.config[:agent_host] = '10.10.10.10'

    if File.exist?('/sbin/ip')
      addr = `/sbin/ip route | awk '/default/ { print $3 }'`.strip
      stub_request(:get, "http://#{addr}:42699/")
        .to_timeout
    end

    stub_request(:get, "http://10.10.10.10:42699/")
      .to_timeout.times(3).then
      .to_return(status: 200, body: "", headers: {})

    discovery = Minitest::Mock.new
    discovery.expect(:delete_observers, discovery, [])
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentActivationObserver])
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentReportingObserver])
    discovery.expect(:swap, discovery, [])

    subject = Instana::Backend::HostAgent.new(discovery: discovery)

    FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/ecs', '/proc')
      subject.spawn_background_thread
    end

    subject.future.value!

    discovery.verify
  ensure
    ::Instana.config[:agent_host] = '127.0.0.1'
    ENV['INSTANA_TEST'] = 'true'
  end

  def test_discovery_value
    discovery = Concurrent::Atom.new({'pid' => 1})
    subject = Instana::Backend::HostAgent.new(discovery: discovery)
    assert_equal 1, subject.source[:e]
  end
end
