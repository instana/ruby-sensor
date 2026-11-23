# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/resource'

class ResourceTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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
      K_SERVICE K_REVISION FUNCTIONS_WORKER_RUNTIME WEBSITE_SITE_NAME
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
      stub_rbconfig('linux-gnu') { assert_equal 'abc123', R.send(:host_id) }
    end
  end

  def test_host_id_falls_back_to_dbus_machine_id
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/var/lib/dbus')
      File.write('/var/lib/dbus/machine-id', "fallback-id\n")
      R.reset!
      stub_rbconfig('linux-gnu') { assert_equal 'fallback-id', R.send(:host_id) }
    end
  end

  def test_host_id_returns_nil_when_no_file
    FakeFS.with_fresh do
      R.reset!
      stub_rbconfig('linux-gnu') { assert_nil R.send(:host_id) }
    end
  end

  def test_host_id_present_in_default_resource_on_linux
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/etc')
      File.write('/etc/machine-id', "machine-xyz\n")
      stub_rbconfig('linux-gnu') do
        R.reset!
        assert_equal 'machine-xyz', R.instance[SC::HOST_ID]
      end
    end
  end

  def test_host_id_on_macos_reads_ioplatformuuid
    output = <<~IOREG
      +-o Root  <class IORegistryEntry>
        +-o MacBookPro  <class IOPlatformExpertDevice>
          {
            "IOPlatformUUID" = "11111111-2222-3333-4444-555555555555"
            "manufacturer" = <"Apple Inc.">
          }
    IOREG
    stub_rbconfig('arm-apple-darwin23') do
      with_run_command(output) { assert_equal '11111111-2222-3333-4444-555555555555', R.send(:host_id) }
    end
  end

  def test_host_id_on_macos_returns_nil_when_command_fails
    stub_rbconfig('arm-apple-darwin23') do
      with_run_command(nil) { assert_nil R.send(:host_id) }
    end
  end

  def test_host_id_on_macos_returns_nil_when_output_unparseable
    stub_rbconfig('arm-apple-darwin23') do
      with_run_command('garbage') { assert_nil R.send(:host_id) }
    end
  end

  def test_host_id_returns_nil_on_unknown_os
    stub_rbconfig('aix7.1') { assert_nil R.send(:host_id) }
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
      stub_rbconfig('linux-gnu') do
        R.reset!
        assert_equal 'stable-host-id', R.instance[SC::SERVICE_INSTANCE_ID]
      end
    end
  end

  def test_service_instance_id_falls_back_to_hostname_pid
    FakeFS.with_fresh do
      stub_rbconfig('linux-gnu') do
        R.reset!
        instance_id = R.instance[SC::SERVICE_INSTANCE_ID]
        assert_match(/.+:\d+/, instance_id, 'fallback should be hostname:pid')
      end
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

  # ─── Azure Functions ───────────────────────────────────────────────────────

  def test_azure_functions_attributes_set_when_env_present
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'ruby'
    ENV['WEBSITE_SITE_NAME']        = 'my-func-app'
    R.reset!
    attrs = R.instance
    assert_equal 'azure',           attrs[SC::CLOUD_PROVIDER]
    assert_equal 'azure_functions', attrs[SC::CLOUD_PLATFORM]
  end

  def test_azure_functions_not_detected_without_website_site_name
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'ruby'
    R.reset!
    refute R.instance.key?(SC::CLOUD_PROVIDER)
    refute R.instance.key?(SC::CLOUD_PLATFORM)
  end

  def test_azure_functions_not_detected_without_functions_worker_runtime
    ENV['WEBSITE_SITE_NAME'] = 'my-web-app'
    R.reset!
    refute R.instance.key?(SC::CLOUD_PROVIDER)
  end

  def test_azure_attributes_in_faas_attrs_not_container_attrs
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'ruby'
    ENV['WEBSITE_SITE_NAME']        = 'my-func-app'
    R.reset!
    assert_equal 'azure_functions', R.send(:faas_attributes).attributes[SC::CLOUD_PLATFORM]
    refute R.send(:container_attributes).attributes.key?(SC::CLOUD_PLATFORM)
  end

  # ─── container.id ──────────────────────────────────────────────────────────

  CONTAINER_ID = ('a1b2c3d4' * 8).freeze

  def test_container_id_from_cgroup_v1_docker_path
    with_proc_files('/proc/self/cgroup' => "12:cpu:/docker/#{CONTAINER_ID}\n") do
      assert_equal CONTAINER_ID, R.send(:extract_container_id)
    end
  end

  def test_container_id_from_cgroup_v1_systemd_scope
    with_proc_files('/proc/self/cgroup' => "1:name=systemd:/system.slice/docker-#{CONTAINER_ID}.scope\n") do
      assert_equal CONTAINER_ID, R.send(:extract_container_id)
    end
  end

  def test_container_id_from_cgroup_v1_kubernetes_containerd
    path = "/kubepods.slice/kubepods-pod1.slice/cri-containerd-#{CONTAINER_ID}.scope"
    with_proc_files('/proc/self/cgroup' => "0::#{path}\n") do
      assert_equal CONTAINER_ID, R.send(:extract_container_id)
    end
  end

  def test_container_id_from_cgroup_v2_docker_mountinfo
    mountinfo = "612 598 254:1 /var/lib/docker/containers/#{CONTAINER_ID}/hostname /etc/hostname rw - ext4 /dev/vda1 rw\n"
    with_proc_files('/proc/self/cgroup' => "0::/\n", '/proc/self/mountinfo' => mountinfo) do
      assert_equal CONTAINER_ID, R.send(:extract_container_id)
    end
  end

  def test_container_id_from_cgroup_v2_podman_mountinfo
    mountinfo = "700 650 0:50 /containers/storage/overlay-containers/#{CONTAINER_ID}/userdata/hostname /etc/hostname rw - tmpfs tmpfs rw\n"
    with_proc_files('/proc/self/cgroup' => "0::/\n", '/proc/self/mountinfo' => mountinfo) do
      assert_equal CONTAINER_ID, R.send(:extract_container_id)
    end
  end

  def test_container_id_nil_when_not_in_container
    with_proc_files('/proc/self/cgroup' => "0::/user.slice/session-1.scope\n",
                    '/proc/self/mountinfo' => "22 28 0:21 / /proc rw - proc proc rw\n") do
      assert_nil R.send(:extract_container_id)
    end
  end

  def test_container_id_nil_when_proc_files_missing
    FakeFS.with_fresh do
      assert_nil R.send(:extract_container_id)
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

  def with_proc_files(files)
    FakeFS.with_fresh do
      FileUtils.mkdir_p('/proc/self')
      files.each { |path, content| File.write(path, content) }
      yield
    end
  end

  # Replaces Resource.run_command with a stub returning +output+ for the duration of the block.
  def with_run_command(output, &block)
    R.stub(:run_command, output, &block)
  end

  def stub_rbconfig(host_os_value)
    original = RbConfig::CONFIG['host_os']
    RbConfig::CONFIG['host_os'] = host_os_value
    yield
  ensure
    RbConfig::CONFIG['host_os'] = original
  end
end
