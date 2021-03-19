# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AgentTest < Minitest::Test
  def test_setup
    ENV['INSTANA_TEST'] = nil
    ::Instana.config[:agent_host] = '10.10.10.10'

    stub_request(:get, "http://10.10.10.10:42699/")
      .to_return(status: 200, body: "", headers: {})

    discovery = Minitest::Mock.new
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentActivationObserver])
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentReportingObserver])

    subject = Instana::Backend::Agent.new(discovery: discovery)
    subject.setup

    discovery.verify
  ensure
    ::Instana.config[:agent_host] = '127.0.0.1'
    ENV['INSTANA_TEST'] = 'true'
  end

  def test_discovery_value
    discovery = Concurrent::Atom.new({'pid' => 1})
    subject = Instana::Backend::Agent.new(discovery: discovery)
    assert_equal 1, subject.report_pid
  end
end
