# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class ServerlesAgentTest < Minitest::Test
  def test_report
    stub_request(:post, "http://10.10.10.10:9292//bundle")
      .to_return(status: 500)
      .to_return(status: 200)

    host_name = Class.new do
      def host_name
        'hello'
      end
    end.new

    snapshots = [Instana::Snapshot::RubyProcess.new, host_name]
    subject = Instana::Backend::ServerlessAgent.new(snapshots, timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/', logger: Logger.new('/dev/null'))

    subject.timer.block.call
    subject.timer.block.call
  end

  def test_ready
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/')
    assert subject.ready?
  end

  def test_extra_headers
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/')
    assert_equal [], subject.extra_headers
  end

  def test_secret_values
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/')
    assert_equal({"matcher" => "contains-ignore-case", "list" => %w[key password secret]}, subject.secret_values)
  end

  def test_spawn_background_thread
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/')
    subject.spawn_background_thread

    assert subject.timer.running
  end

  def test_source
    snapshot = Class.new do
      def source
        {test: 1}
      end
    end.new
    subject = Instana::Backend::ServerlessAgent.new([snapshot], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/')

    assert_equal({test: 1}, subject.source)
    assert_equal({test: 1}, subject.source)
  end

  def test_missing_source
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/', logger: Logger.new('/dev/null'))

    assert_equal({}, subject.source)
  end

  def test_report_error
    stub_request(:post, "http://10.10.10.10:9292//bundle")
      .to_return(status: 500)

    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/', logger: Logger.new('/dev/null'))

    subject.timer.block.call
  end

  def test_start
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/', logger: Logger.new('/dev/null'))
    assert subject.respond_to? :start
  end

  def test_after_fork
    subject = Instana::Backend::ServerlessAgent.new([], timer_class: MockTimer, backend_uri: 'http://10.10.10.10:9292/', logger: Logger.new('/dev/null'))
    assert subject.respond_to? :after_fork
  end
end
