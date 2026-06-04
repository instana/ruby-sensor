# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require 'socket'
require 'opentelemetry/semantic_conventions'
require_relative '../../util'

module Instana
  module Exporter
    module Otlp
      # Resource represents a resource, which captures identifying information about the entities
      # for which telemetry (metrics or traces) is reported.
      # This follows OpenTelemetry semantic conventions for resource attributes
      class Resource
        class << self
          private :new

          # Returns a newly created {Resource} with the specified attributes
          #
          # @param [Hash{String => String, Numeric, Boolean}] attributes Hash of key-value pairs to be used
          #   as attributes for this resource
          # @return [Resource]
          def create(attributes = {})
            frozen_attributes = attributes.each_with_object({}) do |(k, v), memo|
              memo[-k] = v.freeze
            end.freeze

            new(frozen_attributes)
          end

          # Returns the default resource with standard attributes
          #
          # @return [Resource]
          def default
            @default ||= create(OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'ruby-service')
                         .merge(process)
                         .merge(telemetry_sdk)
                         .merge(service_name_from_env)
                         .merge(optional_attributes)
                         .merge(container_attributes)
          end

          # Get the global resource instance (singleton pattern)
          # This method provides backward compatibility with the previous API
          #
          # @return [Hash] Resource attributes as a hash
          def instance
            @instance ||= default.attributes
          end

          # Reset the resource instance (useful for testing)
          # This method provides backward compatibility with the previous API
          def reset!
            @instance = nil
            @default = nil
          end

          # Returns telemetry SDK resource attributes
          #
          # @return [Resource]
          def telemetry_sdk
            create(
              OpenTelemetry::SemanticConventions::Resource::TELEMETRY_SDK_NAME => 'instana',
              OpenTelemetry::SemanticConventions::Resource::TELEMETRY_SDK_LANGUAGE => 'ruby',
              OpenTelemetry::SemanticConventions::Resource::TELEMETRY_SDK_VERSION => ::Instana::VERSION
            )
          end

          # Returns process resource attributes
          #
          # @return [Resource]
          def process
            create(
              OpenTelemetry::SemanticConventions::Resource::PROCESS_PID => Process.pid,
              OpenTelemetry::SemanticConventions::Resource::PROCESS_COMMAND => $PROGRAM_NAME,
              OpenTelemetry::SemanticConventions::Resource::PROCESS_EXECUTABLE_NAME => File.basename($PROGRAM_NAME),
              OpenTelemetry::SemanticConventions::Resource::PROCESS_RUNTIME_NAME => RUBY_ENGINE,
              OpenTelemetry::SemanticConventions::Resource::PROCESS_RUNTIME_VERSION => RUBY_VERSION,
              OpenTelemetry::SemanticConventions::Resource::PROCESS_RUNTIME_DESCRIPTION => RUBY_DESCRIPTION
            )
          end

          private

          # Returns service name from environment variables
          #
          # @return [Resource]
          def service_name_from_env
            service_name = ENV['OTEL_SERVICE_NAME'] ||
                           ENV['INSTANA_SERVICE_NAME'] ||
                           ::Instana::Util.get_app_name

            return create({}) unless service_name

            create(OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => service_name)
          end

          # Returns optional resource attributes (host, service version, service instance id)
          #
          # @return [Resource]
          def optional_attributes
            attrs = {}

            # Add service instance id (hostname:pid format)
            host = hostname
            attrs[OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID] = "#{host}:#{Process.pid}"

            # Add service version if available
            version = ENV['OTEL_SERVICE_VERSION'] || ENV['INSTANA_SERVICE_VERSION'] || detect_app_version
            attrs[OpenTelemetry::SemanticConventions::Resource::SERVICE_VERSION] = version if version

            # Add host attributes if available
            attrs[OpenTelemetry::SemanticConventions::Resource::HOST_NAME] = host if host && host != 'unknown'

            arch = host_architecture
            attrs[OpenTelemetry::SemanticConventions::Resource::HOST_ARCH] = arch if arch

            create(attrs)
          end

          # Returns container and cloud platform resource attributes
          #
          # @return [Resource]
          def container_attributes
            attrs = {}

            # Check for Docker
            if File.exist?('/.dockerenv') || File.exist?('/proc/self/cgroup')
              attrs[OpenTelemetry::SemanticConventions::Resource::CONTAINER_RUNTIME] = 'docker'
              container_id = extract_container_id
              attrs[OpenTelemetry::SemanticConventions::Resource::CONTAINER_ID] = container_id if container_id
            end

            # Check for Kubernetes
            if ENV['KUBERNETES_SERVICE_HOST']
              attrs[OpenTelemetry::SemanticConventions::Resource::K8S_POD_NAME] = ENV['HOSTNAME']
              attrs[OpenTelemetry::SemanticConventions::Resource::K8S_NAMESPACE_NAME] = ENV['KUBERNETES_NAMESPACE'] if ENV['KUBERNETES_NAMESPACE']
            end

            # Check for AWS ECS/Fargate
            if ENV['ECS_CONTAINER_METADATA_URI'] || ENV['ECS_CONTAINER_METADATA_URI_V4']
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'aws'
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'aws_ecs'
            end

            # Check for AWS Lambda
            if ENV['AWS_LAMBDA_FUNCTION_NAME']
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'aws'
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'aws_lambda'
              attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_NAME] = ENV['AWS_LAMBDA_FUNCTION_NAME']
              attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION] = ENV['AWS_LAMBDA_FUNCTION_VERSION'] if ENV['AWS_LAMBDA_FUNCTION_VERSION']
            end

            # Check for Google Cloud Run
            if ENV['K_SERVICE']
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'gcp'
              attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'gcp_cloud_run'
              attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_NAME] = ENV['K_SERVICE']
              attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION] = ENV['K_REVISION'] if ENV['K_REVISION']
            end

            create(attrs)
          end

          # Get hostname
          #
          # @return [String] Hostname
          def hostname
            Socket.gethostname
          rescue StandardError
            'unknown'
          end

          # Get host architecture
          #
          # @return [String] Host architecture
          def host_architecture
            RbConfig::CONFIG['host_cpu']
          end

          # Extract container ID from cgroup file
          #
          # @return [String, nil] Container ID
          def extract_container_id
            return nil unless File.exist?('/proc/self/cgroup')

            File.readlines('/proc/self/cgroup').each do |line|
              # Docker container ID is typically in the cgroup path
              match = line.match(%r{/docker/([a-f0-9]{64})})
              return match[1] if match
            end

            nil
          rescue StandardError
            nil
          end

          # Detect application version from various sources
          #
          # @return [String, nil] Application version
          def detect_app_version
            # Try to get version from Rails
            if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
              app_class = ::Rails.application.class
              return app_class::VERSION if app_class.const_defined?(:VERSION)
            end

            # Try to get version from Gemfile.lock
            if File.exist?('Gemfile.lock')
              lockfile = File.read('Gemfile.lock')
              # Look for the main gem version (first gem in the file)
              match = lockfile.match(/^\s{4}(\S+)\s+\(([^)]+)\)/)
              return match[2] if match
            end

            nil
          rescue StandardError
            nil
          end
        end

        # @api private
        # The constructor is private and only for use internally by the class.
        # Users should use the {create} factory method to obtain a {Resource}
        # instance.
        #
        # @param [Hash<String, String>] frozen_attributes Frozen-hash of frozen-string
        #   key-value pairs to be used as attributes for this resource
        # @return [Resource]
        def initialize(frozen_attributes)
          @attributes = frozen_attributes
        end

        # Returns an enumerator for attributes of this {Resource}
        #
        # @return [Enumerator]
        def attribute_enumerator
          @attribute_enumerator ||= attributes.to_enum
        end

        # Returns a new, merged {Resource} by merging the current {Resource} with
        # the other {Resource}. In case of a collision, the other {Resource}
        # takes precedence
        #
        # @param [Resource] other The other resource to merge
        # @return [Resource] A new resource formed by merging the current resource
        #   with other
        def merge(other)
          return self unless other.is_a?(Resource)

          self.class.send(:new, attributes.merge(other.send(:attributes)).freeze)
        end

        # Returns the attributes hash for this resource
        #
        # @return [Hash] The frozen attributes hash
        attr_reader :attributes
      end
    end
  end
end
