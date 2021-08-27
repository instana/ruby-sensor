# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentReportingObserverTest < Minitest::Test
  def test_start_stop
    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    refute subject.report_timer.running

    subject.update(Time.now, nil, true)
    assert subject.report_timer.running

    subject.update(Time.now, nil, nil)
    refute subject.report_timer.running

    subject.update(Time.now - 500, nil, true)
    refute subject.report_timer.running
  end

  def test_report
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  end

  def test_report_fail
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 500)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
    assert_nil discovery.value
  end

  def test_agent_action
    action = JSON.dump(
      action: 'ruby.source',
      messageId: 'test',
      args: {file: 'test_helper.rb'}
    )

    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200, body: action)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/response.0?messageId=test")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  end

  def test_agent_actions
    action = JSON.dump([
                         action: 'ruby.source',
                         messageId: 'test',
                         args: {file: 'test_helper.rb'}
                       ])

    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200, body: action)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/response.0?messageId=test")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  end

  def test_agent_action_error
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200, body: 'INVALID')

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  end

  def test_disable_metrics
    ::Instana.config[:metrics][:enabled] = false

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  ensure
    ::Instana.config[:metrics][:enabled] = true
  end

  def test_disable_metrics_memory
    ::Instana.config[:metrics][:memory][:enabled] = false

    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .with(body: ->(data) { (JSON.parse(data).keys & ['exec_args', 'memory']).length.eql?(0) })
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  ensure
    ::Instana.config[:metrics][:memory][:enabled] = true
  end

  def test_disable_gc
    ::Instana.config[:metrics][:gc][:enabled] = false

    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .with(body: ->(data) { (JSON.parse(data).keys & ['gc']).length.eql?(0) })
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  ensure
    ::Instana.config[:metrics][:gc][:enabled] = true
  end

  def test_disable_thread
    ::Instana.config[:metrics][:thread][:enabled] = false

    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .with(body: ->(data) { (JSON.parse(data).keys & ['thread']).length.eql?(0) })
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  ensure
    ::Instana.config[:metrics][:thread][:enabled] = true
  end

  def test_disable_tracing
    ::Instana.config[:tracing][:enabled] = false

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.report_timer.block.call
  ensure
    ::Instana.config[:tracing][:enabled] = true
  end

  def test_report_traces
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    processor = Class.new do
      def send
        yield([{n: 'test'}])
      end
    end.new

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

    subject.report_timer.block.call
    refute_nil discovery.value
  end

  def test_report_traces_error
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.1234")
      .to_return(status: 500)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    processor = Class.new do
      def send
        yield([{n: 'test'}])
      end
    end.new

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

    subject.report_timer.block.call
    assert_nil discovery.value
  end

  def test_report_standard_error
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    processor = Class.new do
      def send
        raise 'Standard Error'
      end
    end.new

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor, logger: Logger.new('/dev/null'))

    subject.report_timer.block.call
    assert_equal({"pid" => 1234}, discovery.value)
  end
end
