# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/resource'

class ResourceTest < Minitest::Test
  R = Instana::Exporter::Otlp::Resource
  SC = OpenTelemetry::SemanticConventions::Resource

  def setup
    R.reset!
  end

  def teardown
    R.reset!
    # Clean up any env vars set during tests
    %w[
      OTEL_SERVICE_NAME INSTANA_SERVICE_NAME OTEL_SERVICE_VERSION INSTANA_SERVICE_VERSION
      AWS_LAMBDA_FUNCTION_NAME AWS_LAMBDA_FUNCTION_VERSION AWS_LAMBDA_FUNCTION_ARN
      KUBERNETES_SERVICE_HOST MY_POD_UID KUBERNETES_NAMESPACE
      ECS_CONTAINER_METADATA_URI ECS_CONTAINER_METADATA_URI_V4
      K_SERVICE K_REVISION
    ].each { |k| ENV.delete(k) }
  end

  # ─── create / merge ────────────────────────────────────────────────────────

  def test_create_freezes_keys_and_values
    r = R.create('foo' => 'bar')
    assert r.attributes.frozen?
    assert r.attributes.keys.all?(&:frozen?)
    assert r.attributes.values.all?(&:frozen?)
  end

  def test_create_does_not_negate_key
    r = R.create('service.name' => 'my-app')
    assert_equal 'my-app', r.attributes['service.name'],
                 'key must not be negated (old memo[-k] bug)'
  end

  def test_merge_other_takes_precedence
    base  = R.create('k' => 'base')
    other = R.create('k' => 'other')
    merged = base.merge(other)
    assert_equal 'other', merged.attributes['k']
  end

  def test_merge_with_non_resource_returns_self
    r = R.create('k' => 'v')
    assert_same r, r.merge('not a resource')
  end

  # ─── telemetry SDK ─────────────────────────────────────────────────────────

  def test_telemetry_sdk_attributes
    attrs = R.telemetry_sdk.attributes
    assert_equal 'instana', attrs[SC::TELEMETRY_SDK_NAME]
    assert_equal 'ruby',    attrs[SC::TELEMETRY_SDK_LANGUAGE]
    assert_equal Instana::VERSION, attrs[SC::TELEMETRY_SDK_VERSION]
  end

  # ─── process ───────────────────────────────────────────────────────────────

  def test_process_attributes
    attrs = R.process.attributes
    assert_equal Process.pid,   attrs[SC::PROCESS_PID]
    assert_equal RUBY_ENGINE,   attrs[SC::PROCESS_RUNTIME_NAME]
    assert_equal RUBY_VERSION,  attrs[SC::PROCESS_RUNTIME_VERSION]
  end

  # ─── os.type ───────────────────────────────────────────────────────────────

  def test_os_type_is_present_and_non_empty
    attrs = R.default.attributes
    os = attrs[SC::OS_TYPE]
    refute_nil os, 'os.type must be present (Required per v2 spec)'
    refute_empty os
  end

  def test_detect_os_type_linux
    stub_rbconfig('linux-gnu') do
      assert_equal 'linux', R.send(:detect_os_type)
    end
  end

  def test_detect_os_type_darwin
    stub_rbconfig('arm-apple-darwin23') do
      assert_equal 'darwin', R.send(:detect_os_type)
    end
  end

  def test_detect_os_type_windows
    stub_rbconfig('x86_64-mingw32') do
      assert_equal 'windows', R.send(:detect_os_type)
    end
  end

  def test_detect_os_type_unknown_falls_back_to_raw
    stub_rbconfig('aix7.1') do
      assert_equal 'aix7.1', R.send(:detect_os_type)
    end
  end

  # ─── host.id ───────────────────────────────────────────────────────────────

  def test_host_id_reads_machine_id_file
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/etc')
      File.write('/etc/machine-id', "abc123\n")
      R.reset!
      assert_equal 'abc123', R.send(:host_id)
    end
  end

  def test_host_id_falls_back_to_dbus_machine_id
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/var/lib/dbus')
      File.write('/var/lib/dbus/machine-id', "fallback-id\n")
      R.reset!
      assert_equal 'fallback-id', R.send(:host_id)
    end
  end

  def test_host_id_returns_nil_when_no_file
    FakeFS.with_fresh do
      R.reset!
      assert_nil R.send(:host_id)
    end
  end

  def test_host_id_present_in_default_resource_on_linux
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/etc')
      File.write('/etc/machine-id', "machine-xyz\n")
      R.reset!
      assert_equal 'machine-xyz', R.instance[SC::HOST_ID]
    end
  end

  # ─── service.instance.id priority ─────────────────────────────────────────

  def test_service_instance_id_uses_pod_uid_over_hostname_pid
    FakeFS.with_fresh do
      ENV['MY_POD_UID'] = 'pod-uid-abc'
      R.reset!
      assert_equal 'pod-uid-abc', R.instance[SC::SERVICE_INSTANCE_ID]
    end
  ensure
    ENV.delete('MY_POD_UID')
  end

  def test_service_instance_id_uses_host_id_over_hostname_pid
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/etc')
      File.write('/etc/machine-id', "stable-host-id\n")
      R.reset!
      assert_equal 'stable-host-id', R.instance[SC::SERVICE_INSTANCE_ID]
    end
  end

  def test_service_instance_id_falls_back_to_hostname_pid
    FakeFS.with_fresh do
      R.reset!
      instance_id = R.instance[SC::SERVICE_INSTANCE_ID]
      assert_match(/.+:\d+/, instance_id, 'fallback should be hostname:pid')
    end
  end

  # ─── k8s.pod.uid ───────────────────────────────────────────────────────────

  def test_k8s_pod_uid_set_when_env_present
    ENV['KUBERNETES_SERVICE_HOST'] = '10.0.0.1'
    ENV['MY_POD_UID']              = 'pod-uid-xyz'
    R.reset!
    assert_equal 'pod-uid-xyz', R.instance[SC::K8S_POD_UID]
  ensure
    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('MY_POD_UID')
  end

  def test_k8s_pod_uid_absent_when_env_missing
    ENV['KUBERNETES_SERVICE_HOST'] = '10.0.0.1'
    ENV.delete('MY_POD_UID')
    R.reset!
    refute R.instance.key?(SC::K8S_POD_UID)
  ensure
    ENV.delete('KUBERNETES_SERVICE_HOST')
  end

  # ─── Lambda ARN cloud attributes ───────────────────────────────────────────

  def test_parse_lambda_arn_extracts_region_and_account
    arn = 'arn:aws:lambda:us-east-1:123456789012:function:my-fn'
    result = R.send(:parse_lambda_arn, arn)
    assert_equal 'us-east-1',      result[SC::CLOUD_REGION]
    assert_equal '123456789012',   result[SC::CLOUD_ACCOUNT_ID]
    assert_equal arn,              result[R::CLOUD_RESOURCE_ID]
  end

  def test_lambda_cloud_attributes_in_default_resource
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'
    ENV['AWS_LAMBDA_FUNCTION_ARN']  = 'arn:aws:lambda:eu-west-1:999999999999:function:my-fn'
    R.reset!
    attrs = R.instance
    assert_equal 'eu-west-1',      attrs[SC::CLOUD_REGION]
    assert_equal '999999999999',   attrs[SC::CLOUD_ACCOUNT_ID]
    assert_equal 'arn:aws:lambda:eu-west-1:999999999999:function:my-fn',
                 attrs[R::CLOUD_RESOURCE_ID]
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    ENV.delete('AWS_LAMBDA_FUNCTION_ARN')
  end

  def test_parse_lambda_arn_returns_empty_hash_on_bad_input
    assert_equal({}, R.send(:parse_lambda_arn, nil))
    assert_equal({}, R.send(:parse_lambda_arn, ''))
  end

  def test_lambda_no_arn_env_skips_cloud_attributes
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'
    ENV.delete('AWS_LAMBDA_FUNCTION_ARN')
    R.reset!
    refute R.instance.key?(SC::CLOUD_REGION)
    refute R.instance.key?(SC::CLOUD_ACCOUNT_ID)
    refute R.instance.key?(R::CLOUD_RESOURCE_ID)
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
  end

  # ─── container runtime detection ──────────────────────────────────────────

  def test_docker_detected_on_linux
    FakeFS.with_fresh do
      FileUtils.touch('/.dockerenv')
      stub_rbconfig('linux-gnu') do
        R.reset!
        assert_equal 'docker', R.instance[SC::CONTAINER_RUNTIME]
      end
    end
  end

  def test_podman_detected_on_linux_takes_priority_over_dockerenv
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/run')
      FileUtils.touch('/run/.containerenv')
      FileUtils.touch('/.dockerenv')
      stub_rbconfig('linux-gnu') do
        R.reset!
        assert_equal 'podman', R.instance[SC::CONTAINER_RUNTIME]
      end
    end
  end

  def test_podman_detected_on_linux_without_dockerenv
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/run')
      FileUtils.touch('/run/.containerenv')
      stub_rbconfig('linux-gnu') do
        R.reset!
        assert_equal 'podman', R.instance[SC::CONTAINER_RUNTIME]
      end
    end
  end

  def test_no_container_runtime_detected_on_non_linux
    FakeFS.with_fresh do
      # Even if the Linux sentinel files somehow existed, non-Linux must be skipped
      FileUtils.touch('/.dockerenv')
      stub_rbconfig('arm-apple-darwin23') do
        R.reset!
        refute R.instance.key?(SC::CONTAINER_RUNTIME),
               'container.runtime must not be set on non-Linux'
      end
    end
  end

  # ─── Lambda is NOT part of container_attributes ───────────────────────────

  def test_lambda_attributes_not_in_container_attrs
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'
    R.reset!
    container_attrs = R.send(:container_attributes).attributes
    refute container_attrs.key?(SC::FAAS_NAME),
           'faas.name must not appear inside container_attributes'
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
  end

  def test_lambda_attributes_in_faas_attrs
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'
    R.reset!
    faas_attrs = R.send(:faas_attributes).attributes
    assert_equal 'my-fn', faas_attrs[SC::FAAS_NAME]
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
  end

  private

  def stub_rbconfig(host_os_value)
    original = RbConfig::CONFIG['host_os']
    RbConfig::CONFIG['host_os'] = host_os_value
    yield
  ensure
    RbConfig::CONFIG['host_os'] = original
  end
end
