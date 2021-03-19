# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RequestClientTest < Minitest::Test
  def test_send_request_simple
    stub_request(:get, 'http://example.com:9292/')
      .to_return(body: 'ok', status: '200')

    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    response = subject.send_request('GET', '/')

    assert response.ok?
    assert 'ok', response.body
  end

  def test_send_request_json
    stub_request(:post, 'http://example.com:9292/')
      .with(body: '{"key":"value"}')
      .to_return(body: '{"ok": true}', status: '200')

    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    response = subject.send_request('POST', '/', {key: 'value'})

    assert response.ok?
    assert_equal({"ok" => true}, response.json)
  end

  def test_send_request_failure
    stub_request(:get, 'http://example.com:9292/')
      .to_return(status: '500')

    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    response = subject.send_request('GET', '/')

    refute response.ok?
  end

  def test_fileno
    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    assert_nil subject.fileno
  end

  def test_inode
    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    subject.define_singleton_method(:fileno) { '0' } # This is the cleanest way to fake it so it works across all test environments
    FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      Dir.mkdir('/proc/self/fd')
      File.symlink('/proc/self/sched', '/proc/self/fd/0')

      assert_equal '/proc/self/sched', subject.inode
    end
  end

  def test_inode_no_proc
    subject = Instana::Backend::RequestClient.new('example.com', 9292)
    assert_nil subject.inode
  end
end
