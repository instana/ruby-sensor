# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentTest < Minitest::Test
  def test_spawn_background_thread
    ENV['INSTANA_TEST'] = nil
    agent_host = '10.10.10.10'
    ::Instana.config[:agent_host] = agent_host

    if File.exist?('/proc/net/route')
      default_gateway_hex = lambda {
        File.open('/proc/net/route', 'r') do |file|
          file.each_line do |line|
            columns = line.split("\t")
            if columns[1] == '00000000' && columns[1] == columns[7]
              return columns[2]
            end
          end
        end
      }.call

      addr = default_gateway_hex.scan(/.{2}/).map(&:hex).reverse.join('.')
      stub_request(:get, "http://#{addr}:42699/")
        .to_timeout
    end

    stub_request(:get, "http://#{agent_host}:42699/")
      .to_timeout.times(3).then
      .to_return(status: 200, body: "", headers: {})

    discovery = Minitest::Mock.new
    discovery.expect(:delete_observers, discovery, [])
    discovery.expect(:observers, discovery, [])
    discovery.expect(:notify_and_delete_observers, discovery, [Object, nil, nil])
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

  def test_extra_headers_from_tracing_config
    discovery = Concurrent::Atom.new(
      {
        'tracing' => {
          'extra-http-headers' => ["X-Header-1", "X-Header-2"]
        }
      }
    )
    subject = Instana::Backend::HostAgent.new(discovery: discovery)
    assert_equal ["X-Header-1", "X-Header-2"], subject.extra_headers
  end

  def test_extra_headers_legacy
    discovery = Concurrent::Atom.new({'extraHeaders' => ["X-Header-3", "X-Header-4"]})
    subject = Instana::Backend::HostAgent.new(discovery: discovery)
    assert_equal ["X-Header-3", "X-Header-4"], subject.extra_headers
  end

  def test_start
    subject = Instana::Backend::HostAgent.new
    assert subject.respond_to? :start
  end

  def test_after_fork
    subject = Instana::Backend::HostAgent.new
    assert subject.respond_to? :after_fork
  end

  def test_announce_retries_on_connection_failure
    agent_host = '10.10.10.10'
    ::Instana.config[:agent_host] = agent_host

    # Simulate connection failures followed by success
    stub_request(:get, "http://#{agent_host}:42699/")
      .to_raise(Errno::ECONNREFUSED).times(3).then
      .to_return(status: 200, body: "", headers: {})

    discovery = Minitest::Mock.new
    discovery.expect(:delete_observers, discovery, [])
    discovery.expect(:observers, discovery, [])
    discovery.expect(:notify_and_delete_observers, discovery, [Object, nil, nil])
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentActivationObserver])
    discovery.expect(:with_observer, discovery, [Instana::Backend::HostAgentReportingObserver])
    discovery.expect(:swap, discovery, [])

    subject = Instana::Backend::HostAgent.new(discovery: discovery)

    FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/ecs', '/proc')
      client = subject.announce
      assert client
      assert_instance_of Instana::Backend::RequestClient, client
    end

    discovery.verify
  ensure
    ::Instana.config[:agent_host] = '127.0.0.1'
  end

  def test_announce_returns_nil_after_max_retries
    agent_host = '10.10.10.10'
    ::Instana.config[:agent_host] = agent_host

    # Simulate persistent connection failures
    stub_request(:get, "http://#{agent_host}:42699/")
      .to_raise(Errno::ECONNREFUSED).times(15)

    discovery = Concurrent::Atom.new(nil)
    subject = Instana::Backend::HostAgent.new(discovery: discovery)

    FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/ecs', '/proc')
      client = subject.announce
      assert_nil client
    end
  ensure
    ::Instana.config[:agent_host] = '127.0.0.1'
  end
end
