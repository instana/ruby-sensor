# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentReportingObserverTest < Minitest::Test
  def test_start_stop
    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    refute subject.metrics_timer.running
    refute subject.traces_timer.running

    subject.update(Time.now, nil, true)
    assert subject.metrics_timer.running
    assert subject.traces_timer.running

    subject.update(Time.now, nil, nil)
    refute subject.metrics_timer.running
    refute subject.traces_timer.running

    subject.update(Time.now - 500, nil, true)
    refute subject.metrics_timer.running
    refute subject.traces_timer.running
  end

  def test_report
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.metrics_timer.block.call
  end

  def test_report_fail
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 500)
    stub_request(:get, "http://127.0.0.1:42699/")
      .to_return(status: 200)
    stub_request(:put, "http://127.0.0.1:42699/com.instana.plugin.ruby.discovery")
      .to_return(status: 200, body: '{"pid": 0}')
    stub_request(:head, "http://127.0.0.1:42699/com.instana.plugin.ruby.0")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.metrics_timer.block.call
    assert_nil discovery.value
  end

  def test_agent_action
    action = JSON.dump(
      {
        action: 'ruby.source',
        messageId: 'test',
        args: {file: 'test_helper.rb'}
      }
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

    subject.metrics_timer.block.call
  end

  def test_agent_actions
    action = JSON.dump([
                         {action: 'ruby.source',
                          messageId: 'test',
                          args: {file: 'test_helper.rb'}}
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

    subject.metrics_timer.block.call
  end

  def test_agent_action_error
    stub_request(:post, "http://10.10.10.10:9292/tracermetrics")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
      .to_return(status: 200, body: 'INVALID')

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 0})

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.metrics_timer.block.call
  end

  def test_disable_metrics
    ::Instana.config[:metrics][:enabled] = false

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.metrics_timer.block.call
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

    subject.metrics_timer.block.call
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

    subject.metrics_timer.block.call
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

    subject.metrics_timer.block.call
  ensure
    ::Instana.config[:metrics][:thread][:enabled] = true
  end

  def test_disable_tracing
    ::Instana.config[:tracing][:enabled] = false

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    subject.traces_timer.block.call
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

    subject.traces_timer.block.call
    refute_nil discovery.value
  end

  def test_report_traces_error
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.1234")
      .to_return(status: 500)

    stub_request(:get, "http://127.0.0.1:42699/")
      .to_return(status: 200)
    stub_request(:put, "http://127.0.0.1:42699/com.instana.plugin.ruby.discovery")
      .to_return(status: 200, body: '{"pid": 1234}')
    stub_request(:head, "http://127.0.0.1:42699/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    processor = Class.new do
      def send
        yield([{n: 'test'}])
      end
    end.new

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

    subject.traces_timer.block.call
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

    subject.traces_timer.block.call
    assert_equal({"pid" => 1234}, discovery.value)
  end

  def test_poll_rate_changes_metrics_timer_interval
    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    # Initially, metrics_timer should have 1 second interval (default)
    assert_equal 1, subject.metrics_timer.opts[:execution_interval]
    refute subject.metrics_timer.running

    # Simulate first discovery with poll_rate = 1 (should keep 1 second interval)
    discovery.swap { {'pid' => 1234, 'plugin' => {'ruby' => {'poll_rate' => 1}}} }
    subject.update(Time.now, nil, true)
    assert subject.metrics_timer.running
    assert_equal 1, subject.metrics_timer.opts[:execution_interval]
    assert_equal({'pid' => 1234, 'plugin' => {'ruby' => {'poll_rate' => 1}}}, discovery.value)

    # Simulate discovery cycle changing poll_rate to 5 seconds
    discovery.swap { {'pid' => 1234, 'plugin' => {'ruby' => {'poll_rate' => 5}}} }
    subject.update(Time.now + 1, nil, true)
    assert subject.metrics_timer.running
    assert_equal 5, subject.metrics_timer.opts[:execution_interval]
    assert_equal({'pid' => 1234, 'plugin' => {'ruby' => {'poll_rate' => 5}}}, discovery.value)

    # Verify traces_timer always stays at 1 second
    assert_equal 1, subject.traces_timer.opts[:execution_interval]
  end

  def test_gc_metrics_normalized_by_poll_rate
    # Verify that poll_rate from discovery is forwarded to GCSnapshot.report
    # and the resulting payload reflects per-second normalization
    gc_snapshot = Instana::Backend::GCSnapshot.instance
    gc_snapshot.report(1) # establish baseline

    fake_stats = {
      heap_live_slots: 60_000,
      heap_free_slots: 12_000,
      minor_gc_count: gc_snapshot.instance_variable_get(:@last_minor_count) + 10,
      major_gc_count: gc_snapshot.instance_variable_get(:@last_major_count) + 4
    }

    reported_poll_rate = nil
    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 0.0) do
        stub_request(:post, "http://10.10.10.10:9292/tracermetrics").to_return(status: 200)
        stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
          .with(body: lambda { |raw|
            data = JSON.parse(raw)
            if data['gc']
              reported_poll_rate = data['gc']
            end
            true
          })
          .to_return(status: 200)

        client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
        discovery = Concurrent::Atom.new({'pid' => 0, 'plugin' => {'ruby' => {'poll_rate' => 5}}})

        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
        subject.metrics_timer.block.call
      end
    end

    # Confirm the GC counts in the payload are normalized by poll_rate=5
    assert_in_delta 2.0, reported_poll_rate['minorGcs'], 0.001  # 10 / 5
    assert_in_delta 0.8, reported_poll_rate['majorGcs'], 0.001  # 4 / 5
  end

  def test_gc_metrics_default_poll_rate_when_missing
    # When discovery payload has no poll_rate, defaults to 1 (no normalization)
    gc_snapshot = Instana::Backend::GCSnapshot.instance
    gc_snapshot.report(1) # establish baseline

    fake_stats = {
      heap_live_slots: 70_000,
      heap_free_slots: 5_000,
      minor_gc_count: gc_snapshot.instance_variable_get(:@last_minor_count) + 6,
      major_gc_count: gc_snapshot.instance_variable_get(:@last_major_count) + 2
    }

    reported_gc = nil
    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 0.0) do
        stub_request(:post, "http://10.10.10.10:9292/tracermetrics").to_return(status: 200)
        stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.0")
          .with(body: lambda { |raw|
            data = JSON.parse(raw)
            reported_gc = data['gc'] if data['gc']
            true
          })
          .to_return(status: 200)

        client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
        # No poll_rate key in discovery
        discovery = Concurrent::Atom.new({'pid' => 0})

        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
        subject.metrics_timer.block.call
      end
    end

    # With poll_rate defaulting to 1, counts should be unscaled
    assert_in_delta 6.0, reported_gc['minorGcs'], 0.001
    assert_in_delta 2.0, reported_gc['majorGcs'], 0.001
  end
end
