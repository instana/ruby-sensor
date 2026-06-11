# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentReportingObserverTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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

  # ============================================================================
  # OTLP EXPORT TESTS (INSTANA_OTLP_ENABLED environment variable)
  # ============================================================================

  def test_otlp_export_enabled_with_env_variable
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    exported_spans = nil
    otlp_exporter = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      def send
        yield([{n: 'test', t: '1234', s: '5678'}])
      end
    end.new

    OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

      subject.traces_timer.block.call
    end

    refute_nil exported_spans, "OTLP exporter should have received spans"
    assert exported_spans.is_a?(Array), "Exported spans should be an array"
    assert_equal 1, exported_spans.length, "Should export 1 converted span"
    otlp_exporter.verify
    refute_nil discovery.value, "Discovery should remain valid after successful export"
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end

  def test_otlp_export_disabled_without_env_variable
    ENV.delete('INSTANA_OTLP_ENABLED')

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

    # Should not create OTLP exporter
    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

    assert_nil subject.instance_variable_get(:@otlp_exporter), "OTLP exporter should not be initialized without env variable"

    subject.traces_timer.block.call
    refute_nil discovery.value, "Discovery should remain valid"
  end

  def test_otlp_export_converts_spans_correctly
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    test_span = {
      n: 'rack',
      t: '1234567890abcdef',
      s: 'fedcba0987654321',
      ts: Time.now.to_i * 1000,
      d: 100,
      k: 1,
      data: {
        http: {
          method: 'GET',
          url: 'http://example.com/test',
          status: 200
        }
      }
    }

    exported_spans = nil
    otlp_exporter = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      attr_reader :test_span

      def initialize(span)
        @test_span = span
      end

      def send
        yield([@test_span])
      end
    end.new(test_span)

    OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

      subject.traces_timer.block.call
    end

    refute_nil exported_spans, "Should export converted spans"
    assert exported_spans.is_a?(Array), "Exported spans should be an array"
    assert_equal 1, exported_spans.length, "Should export 1 converted span"

    # The converter returns OpenTelemetry::SDK::Trace::SpanData
    # Just verify we got a converted span object
    refute_nil exported_spans.first, "Converted span should not be nil"

    otlp_exporter.verify
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end

  def test_otlp_export_failure_triggers_rediscovery
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    stub_request(:get, "http://127.0.0.1:42699/")
      .to_return(status: 200)
    stub_request(:put, "http://127.0.0.1:42699/com.instana.plugin.ruby.discovery")
      .to_return(status: 200, body: '{"pid": 1234}')
    stub_request(:head, "http://127.0.0.1:42699/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    otlp_exporter = Minitest::Mock.new
    # Return FAILURE status code
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::FAILURE) do |_spans|
      OpenTelemetry::SDK::Trace::Export::FAILURE
    end

    processor = Class.new do
      def send
        yield([{n: 'test'}])
      end
    end.new

    OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

      subject.traces_timer.block.call
    end

    otlp_exporter.verify
    assert_nil discovery.value, "Discovery should be reset after export failure"
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end

  def test_otlp_export_with_multiple_spans
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    test_spans = [
      {n: 'rack', t: '1111', s: '2222'},
      {n: 'activerecord', t: '1111', s: '3333', p: '2222'},
      {n: 'redis', t: '1111', s: '4444', p: '2222'}
    ]

    exported_spans = nil
    otlp_exporter = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      attr_reader :test_spans

      def initialize(spans)
        @test_spans = spans
      end

      def send
        yield(@test_spans)
      end
    end.new(test_spans)

    OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

      subject.traces_timer.block.call
    end

    refute_nil exported_spans, "Should export converted spans"
    assert_equal 3, exported_spans.length, "Should export all 3 converted spans"
    otlp_exporter.verify
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end

  def test_otlp_exporter_initialization_with_env_variable
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

    refute_nil subject.instance_variable_get(:@otlp_exporter), "OTLP exporter should be initialized when env variable is set"
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end

  def test_otlp_export_handles_empty_span_batch
    ENV['INSTANA_OTLP_ENABLED'] = 'true'

    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    otlp_exporter = Minitest::Mock.new
    # Should not be called for empty batch

    processor = Class.new do
      def send
        yield([])
      end
    end.new

    OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer, processor: processor)

      subject.traces_timer.block.call
    end

    # Discovery should remain valid even with empty batch
    refute_nil discovery.value, "Discovery should remain valid with empty span batch"
  ensure
    ENV.delete('INSTANA_OTLP_ENABLED')
  end
end
