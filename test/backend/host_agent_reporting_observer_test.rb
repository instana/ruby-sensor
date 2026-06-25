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
  # OTLP EXPORT TESTS (driven by ::Instana.config[:otlp])
  # ============================================================================

  # Helper: stub ::Instana.config[:otlp] for the duration of a block
  def with_otlp_config(overrides = {})
    base = {
      enabled: true,
      endpoint: 'http://localhost:4318/v1/traces',
      timeout: 5_000,
      compression: nil,
      headers: {}
    }
    ::Instana.config[:otlp] = base.merge(overrides)
    yield
  ensure
    ::Instana.config[:otlp] = { enabled: false, endpoint: 'http://localhost:4318/v1/traces',
                                timeout: 10_000, compression: nil, headers: {},
                                certificate: nil, client_key: nil, client_certificate: nil,
                                config_source: 'default' }
  end

  def test_otlp_exporter_initialised_when_config_enabled
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    fake_exporter = Object.new
    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, fake_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
        refute_nil subject.instance_variable_get(:@otlp_exporter),
                   'OTLP exporter should be initialised when config[:otlp][:enabled] is true'
      end
    end
  end

  def test_otlp_exporter_nil_when_config_disabled
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    with_otlp_config(enabled: false) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
      assert_nil subject.instance_variable_get(:@otlp_exporter),
                 'OTLP exporter should be nil when config[:otlp][:enabled] is false'
    end
  end

  def test_otlp_exporter_construction_error_is_rescued
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)
    log_lines = []
    logger    = Logger.new(StringIO.new).tap { |l| l.define_singleton_method(:error) { |msg| log_lines << msg } }

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, ->(**_) { raise StandardError, 'boom' }) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   logger: logger,
                                                                   timer_class: MockTimer)
        assert_nil subject.instance_variable_get(:@otlp_exporter),
                   'Exporter should be nil when construction raises'
        assert log_lines.any? { |l| l.include?('boom') },
               'Error should be logged'
      end
    end
  end

  def test_otlp_exporter_timeout_converted_to_seconds
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)
    received_opts = nil

    with_otlp_config(enabled: true, timeout: 8_000) do
      capture = lambda { |** opts|
        received_opts = opts
        Minitest::Mock.new
      }
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, capture) do
        Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
      end
    end

    assert_in_delta 8.0, received_opts[:timeout], 0.001,
                    'Timeout should be converted from ms to seconds'
  end

  def test_otlp_exporter_passes_compression_when_set
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)
    received_opts = nil

    with_otlp_config(enabled: true, compression: 'gzip') do
      capture = lambda { |**opts|
        received_opts = opts
        Minitest::Mock.new
      }
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, capture) do
        Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
      end
    end

    assert_equal 'gzip', received_opts[:compression]
  end

  def test_otlp_exporter_passes_headers_when_present
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)
    received_opts = nil

    with_otlp_config(enabled: true, headers: { 'x-api-key' => 'secret' }) do
      capture = lambda { |**opts|
        received_opts = opts
        Minitest::Mock.new
      }
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, capture) do
        Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)
      end
    end

    assert_equal({ 'x-api-key' => 'secret' }, received_opts[:headers])
  end

  def test_otlp_export_enabled_exports_spans
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    exported_spans = nil
    otlp_exporter  = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      def send = yield([{n: 'test', t: '1234', s: '5678'}])
    end.new

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   timer_class: MockTimer,
                                                                   processor: processor)
        subject.traces_timer.block.call
      end
    end

    refute_nil exported_spans, 'OTLP exporter should have received spans'
    assert     exported_spans.is_a?(Array)
    assert_equal 1, exported_spans.length
    otlp_exporter.verify
    refute_nil discovery.value, 'Discovery should remain valid after successful export'
  end

  def test_otlp_export_disabled_uses_native_reporting
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby/traces.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    processor = Class.new do
      def send = yield([{n: 'test'}])
    end.new

    with_otlp_config(enabled: false) do
      subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                 timer_class: MockTimer,
                                                                 processor: processor)
      assert_nil subject.instance_variable_get(:@otlp_exporter),
                 'OTLP exporter should not be initialised when disabled'
      subject.traces_timer.block.call
    end

    refute_nil discovery.value, 'Discovery should remain valid'
  end

  def test_otlp_export_converts_spans_correctly
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    test_span = {
      n: 'rack', t: '1234567890abcdef', s: 'fedcba0987654321',
      ts: Time.now.to_i * 1000, d: 100, k: 1,
      data: { http: { method: 'GET', url: 'http://example.com/test', status: 200 } }
    }

    exported_spans = nil
    otlp_exporter  = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      def initialize(span) = @span = span
      def send = yield([@span])
    end.new(test_span)

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   timer_class: MockTimer,
                                                                   processor: processor)
        subject.traces_timer.block.call
      end
    end

    refute_nil exported_spans
    assert_equal 1, exported_spans.length
    refute_nil exported_spans.first
    otlp_exporter.verify
  end

  def test_otlp_export_failure_triggers_rediscovery
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)
    stub_request(:get,  "http://127.0.0.1:42699/")
      .to_return(status: 200)
    stub_request(:put,  "http://127.0.0.1:42699/com.instana.plugin.ruby.discovery")
      .to_return(status: 200, body: '{"pid": 1234}')
    stub_request(:head, "http://127.0.0.1:42699/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    otlp_exporter = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::FAILURE) do |_spans|
      OpenTelemetry::SDK::Trace::Export::FAILURE
    end

    processor = Class.new do
      def send = yield([{n: 'test'}])
    end.new

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   timer_class: MockTimer,
                                                                   processor: processor)
        subject.traces_timer.block.call
      end
    end

    otlp_exporter.verify
    assert_nil discovery.value, 'Discovery should be reset after export failure'
  end

  def test_otlp_export_with_multiple_spans
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    test_spans = [
      {n: 'rack',        t: '1111', s: '2222'},
      {n: 'activerecord', t: '1111', s: '3333', p: '2222'},
      {n: 'redis',        t: '1111', s: '4444', p: '2222'}
    ]

    exported_spans = nil
    otlp_exporter  = Minitest::Mock.new
    otlp_exporter.expect(:export, OpenTelemetry::SDK::Trace::Export::SUCCESS) do |spans|
      exported_spans = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    processor = Class.new do
      def initialize(spans) = @spans = spans
      def send = yield(@spans)
    end.new(test_spans)

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   timer_class: MockTimer,
                                                                   processor: processor)
        subject.traces_timer.block.call
      end
    end

    refute_nil exported_spans
    assert_equal 3, exported_spans.length
    otlp_exporter.verify
  end

  def test_otlp_export_handles_empty_span_batch
    stub_request(:post, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .to_return(status: 200)

    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new({'pid' => 1234})

    otlp_exporter = Minitest::Mock.new # export should never be called

    processor = Class.new do
      def send = yield([])
    end.new

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, otlp_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery,
                                                                   timer_class: MockTimer,
                                                                   processor: processor)
        subject.traces_timer.block.call
      end
    end

    refute_nil discovery.value, 'Discovery should remain valid with empty span batch'
  end

  def test_otlp_exporter_shutdown_on_agent_disconnect
    client    = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    shutdown_called = false
    fake_exporter = Object.new
    fake_exporter.define_singleton_method(:shutdown) { shutdown_called = true }

    with_otlp_config(enabled: true) do
      OpenTelemetry::Exporter::OTLP::Exporter.stub(:new, fake_exporter) do
        subject = Instana::Backend::HostAgentReportingObserver.new(client, discovery, timer_class: MockTimer)

        # Simulate agent going away (new_version.nil? branch)
        subject.update(Time.now, nil, nil)

        assert shutdown_called, 'OTLP exporter should be shut down when agent disconnects'
        assert_nil subject.instance_variable_get(:@otlp_exporter),
                   'OTLP exporter reference should be cleared after shutdown'
      end
    end
  end
end
