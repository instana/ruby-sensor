# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/resource'

class ResourceTest < Minitest::Test
  def setup
    # Reset the resource instance before each test
    Instana::Exporter::Otlp::Resource.reset!
  end

  def test_resource_is_singleton
    resource1 = Instana::Exporter::Otlp::Resource.instance
    resource2 = Instana::Exporter::Otlp::Resource.instance

    assert_same resource1, resource2
  end

  def test_resource_contains_service_attributes
    resource = Instana::Exporter::Otlp::Resource.instance

    assert resource.key?('service.name')
    assert resource.key?('service.instance.id')
    assert_kind_of String, resource['service.name']
    assert_kind_of String, resource['service.instance.id']
  end

  def test_resource_contains_telemetry_sdk_attributes
    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'instana', resource['telemetry.sdk.name']
    assert_equal 'ruby', resource['telemetry.sdk.language']
    assert_equal Instana::VERSION, resource['telemetry.sdk.version']
  end

  def test_resource_contains_process_attributes
    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal Process.pid, resource['process.pid']
    assert_equal 'ruby', resource['process.runtime.name']
    assert_equal RUBY_VERSION, resource['process.runtime.version']
    assert_equal RUBY_DESCRIPTION, resource['process.runtime.description']
    assert_kind_of String, resource['process.executable.name']
  end

  def test_resource_contains_host_attributes
    resource = Instana::Exporter::Otlp::Resource.instance

    assert resource.key?('host.name')
    assert resource.key?('host.arch')
    assert_kind_of String, resource['host.name']
    assert_kind_of String, resource['host.arch']
  end

  def test_service_name_from_environment
    ENV['INSTANA_SERVICE_NAME'] = 'test-service'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'test-service', resource['service.name']
  ensure
    ENV.delete('INSTANA_SERVICE_NAME')
  end

  def test_service_version_from_environment
    ENV['INSTANA_SERVICE_VERSION'] = '2.0.0'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal '2.0.0', resource['service.version']
  ensure
    ENV.delete('INSTANA_SERVICE_VERSION')
  end

  def test_resource_excludes_nil_values
    resource = Instana::Exporter::Otlp::Resource.instance

    resource.each_value do |value|
      refute_nil value, 'Resource should not contain nil values'
    end
  end

  def test_service_instance_id_format
    resource = Instana::Exporter::Otlp::Resource.instance
    instance_id = resource['service.instance.id']

    assert_match(/\w+:\d+/, instance_id, 'Instance ID should be in format hostname:pid')
  end

  def test_otel_service_name_takes_precedence
    ENV['OTEL_SERVICE_NAME'] = 'otel-service'
    ENV['INSTANA_SERVICE_NAME'] = 'instana-service'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'otel-service', resource['service.name']
  ensure
    ENV.delete('OTEL_SERVICE_NAME')
    ENV.delete('INSTANA_SERVICE_NAME')
  end

  def test_otel_service_version_takes_precedence
    ENV['OTEL_SERVICE_VERSION'] = '3.0.0'
    ENV['INSTANA_SERVICE_VERSION'] = '2.0.0'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal '3.0.0', resource['service.version']
  ensure
    ENV.delete('OTEL_SERVICE_VERSION')
    ENV.delete('INSTANA_SERVICE_VERSION')
  end

  def test_kubernetes_attributes
    ENV['KUBERNETES_SERVICE_HOST'] = '10.0.0.1'
    ENV['KUBERNETES_NAMESPACE'] = 'production'
    ENV['HOSTNAME'] = 'my-pod-123'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'my-pod-123', resource['k8s.pod.name']
    assert_equal 'production', resource['k8s.namespace.name']
  ensure
    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_NAMESPACE')
    ENV.delete('HOSTNAME')
  end

  def test_aws_lambda_attributes
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-function'
    ENV['AWS_LAMBDA_FUNCTION_VERSION'] = '1'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'aws', resource['cloud.provider']
    assert_equal 'aws_lambda', resource['cloud.platform']
    assert_equal 'my-function', resource['faas.name']
    assert_equal '1', resource['faas.version']
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    ENV.delete('AWS_LAMBDA_FUNCTION_VERSION')
  end

  def test_aws_ecs_attributes
    ENV['ECS_CONTAINER_METADATA_URI'] = 'http://169.254.170.2/v3'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'aws', resource['cloud.provider']
    assert_equal 'aws_ecs', resource['cloud.platform']
  ensure
    ENV.delete('ECS_CONTAINER_METADATA_URI')
  end

  def test_google_cloud_run_attributes
    ENV['K_SERVICE'] = 'my-service'
    ENV['K_REVISION'] = 'my-service-00001'
    Instana::Exporter::Otlp::Resource.reset!

    resource = Instana::Exporter::Otlp::Resource.instance

    assert_equal 'gcp', resource['cloud.provider']
    assert_equal 'gcp_cloud_run', resource['cloud.platform']
    assert_equal 'my-service', resource['faas.name']
    assert_equal 'my-service-00001', resource['faas.version']
  ensure
    ENV.delete('K_SERVICE')
    ENV.delete('K_REVISION')
  end

  def test_resource_merge
    resource1 = Instana::Exporter::Otlp::Resource.create('key1' => 'value1', 'key2' => 'value2')
    resource2 = Instana::Exporter::Otlp::Resource.create('key2' => 'new_value2', 'key3' => 'value3')

    merged = resource1.merge(resource2)

    assert_equal 'value1', merged.attributes['key1']
    assert_equal 'new_value2', merged.attributes['key2']
    assert_equal 'value3', merged.attributes['key3']
  end

  def test_resource_merge_with_non_resource
    resource = Instana::Exporter::Otlp::Resource.create('key1' => 'value1')
    merged = resource.merge('not a resource')

    assert_same resource, merged
  end

  def test_resource_attribute_enumerator
    resource = Instana::Exporter::Otlp::Resource.create('key1' => 'value1', 'key2' => 'value2')
    enumerator = resource.attribute_enumerator

    assert_kind_of Enumerator, enumerator
    assert_equal 2, enumerator.count
  end

  def test_resource_attributes_are_frozen
    resource = Instana::Exporter::Otlp::Resource.create('key1' => 'value1')

    assert resource.attributes.frozen?
    assert_raises(FrozenError) { resource.attributes['key2'] = 'value2' }
  end

  def test_process_command_attribute
    resource = Instana::Exporter::Otlp::Resource.instance

    assert resource.key?('process.command')
    assert_equal $PROGRAM_NAME, resource['process.command']
  end
end
