# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentLookupTest < Minitest::Test
  def test_lookup
    stub_request(:get, "http://10.10.10.10:42699/")
      .to_return(status: 200)

    subject = Instana::Backend::HostAgentLookup.new('10.10.10.10', 42699)
    client = subject.call

    assert client
    assert client.send_request('GET', '/').ok?
  end

  def test_lookup_no_agent
    stub_request(:get, "http://10.10.10.10:42699/")
      .to_timeout

    subject = Instana::Backend::HostAgentLookup.new('10.10.10.10', 42699)

    client = FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/ecs', '/proc')

      subject.call
    end

    assert_nil client
  end

  def test_lookup_agent_error
    stub_request(:get, "http://10.10.10.10:42699/")
      .to_return(status: 500)

    subject = Instana::Backend::HostAgentLookup.new('10.10.10.10', 42699)

    client = FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/ecs', '/proc')

      subject.call
    end

    assert_nil client
  end

  def test_lookup_with_gateway
    stub_request(:get, "http://10.10.10.10:42699/")
      .to_timeout
    stub_request(:get, "http://172.18.0.1:42699/")
      .to_return(status: 200)

    subject = Instana::Backend::HostAgentLookup.new('10.10.10.10', 42699)

    client = FakeFS do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      subject.call
    end

    assert client
    assert client.send_request('GET', '/').ok?
  end

  def test_lookup_with_gateway_no_destination
    stub_request(:get, "http://10.10.10.10:42699/")
      .to_timeout

    subject = Instana::Backend::HostAgentLookup.new('10.10.10.10', 42699, destination: '11111111')

    client = FakeFS do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      subject.call
    end

    assert_nil client
  end
end
