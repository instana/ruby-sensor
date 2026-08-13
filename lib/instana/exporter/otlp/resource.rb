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
        PROC_SELF_CGROUP    = '/proc/self/cgroup'
        DOCKER_ENV_FILE     = '/.dockerenv'
        PODMAN_CONTAINERENV = '/run/.containerenv'
        # Linux-only stable machine-id paths (systemd and D-Bus fallback).
        # These files do not exist on macOS or Windows; host_id returns nil there.
        MACHINE_ID_PATHS   = %w[/etc/machine-id /var/lib/dbus/machine-id].freeze
        # cloud.resource_id is not yet in the installed semconv gem version
        CLOUD_RESOURCE_ID  = 'cloud.resource_id'

        class << self
          private :new

          # Returns a newly created {Resource} with the specified attributes
          #
          # @param [Hash{String => String, Numeric, Boolean}] attributes Hash of key-value pairs to be used
          #   as attributes for this resource
          # @return [Resource]
          def create(attributes = {})
            frozen_attributes = attributes.each_with_object({}) do |(k, v), memo|
              memo[k.freeze] = v.freeze
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
                         .merge(faas_attributes)
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
            service_name = ENV.fetch('OTEL_SERVICE_NAME', nil) ||
                           ENV.fetch('INSTANA_SERVICE_NAME', nil) ||
                           ::Instana::Util.get_app_name

            return create({}) unless service_name

            create(OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => service_name)
          end

          # Returns optional resource attributes:
          #   os.type, host.name, host.arch, host.id, service.version, service.instance.id
          #
          # service.instance.id priority (v2 spec §General Resource Attributes):
          #   container.id → k8s.pod.uid → host.id → hostname:pid
          #
          # @return [Resource]
          def optional_attributes
            attrs = {}

            # os.type — Required per v2 spec
            attrs[OpenTelemetry::SemanticConventions::Resource::OS_TYPE] = detect_os_type

            host = hostname

            # host.name — Recommended (Conditional) per v2 spec
            attrs[OpenTelemetry::SemanticConventions::Resource::HOST_NAME] = host if host && host != 'unknown'

            # host.arch
            arch = host_architecture
            attrs[OpenTelemetry::SemanticConventions::Resource::HOST_ARCH] = arch if arch

            # host.id — Recommended per v2 spec; stable machine identifier
            hid = host_id
            attrs[OpenTelemetry::SemanticConventions::Resource::HOST_ID] = hid if hid

            # service.version
            version = ENV.fetch('OTEL_SERVICE_VERSION', nil) ||
                      ENV.fetch('INSTANA_SERVICE_VERSION', nil) ||
                      detect_app_version
            attrs[OpenTelemetry::SemanticConventions::Resource::SERVICE_VERSION] = version if version

            # service.instance.id — priority: container.id > k8s.pod.uid > host.id > hostname:pid
            instance_id = extract_container_id ||
                          ENV.fetch('MY_POD_UID', nil) ||
                          hid ||
                          "#{host}:#{Process.pid}"
            attrs[OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID] = instance_id

            create(attrs)
          end

          # Returns container and cloud platform resource attributes.
          # AWS Lambda is intentionally excluded here — it is a FaaS platform,
          # not a container runtime. See faas_attributes for Lambda/Cloud Run.
          #
          # @return [Resource]
          def container_attributes
            attrs = {}

            add_docker_or_podman_attributes(attrs)
            add_kubernetes_attributes(attrs)
            add_aws_ecs_attributes(attrs)

            create(attrs)
          end

          # Returns FaaS (Function-as-a-Service) platform resource attributes.
          # Kept separate from container_attributes because Lambda and Cloud Run
          # are serverless runtimes, not container runtimes.
          #
          # @return [Resource]
          def faas_attributes
            attrs = {}

            add_aws_lambda_attributes(attrs)
            add_cloud_run_attributes(attrs)

            create(attrs)
          end

          # Sets container.runtime and container.id attributes when a container
          # engine is detected. Only runs on Linux since all sentinel paths are
          # Linux-specific.
          def add_docker_or_podman_attributes(attrs)
            return unless linux?

            engine = extract_container_engine
            attrs[OpenTelemetry::SemanticConventions::Resource::CONTAINER_RUNTIME] = engine if engine

            container_id = extract_container_id
            attrs[OpenTelemetry::SemanticConventions::Resource::CONTAINER_ID] = container_id if container_id
          end

          # Detects the container engine by inspecting Linux sentinel files.
          # Returns 'podman', 'docker', or nil if no container environment is found.
          #
          # @return [String, nil]
          def extract_container_engine
            if File.exist?(PODMAN_CONTAINERENV)
              'podman'
            elsif File.exist?(DOCKER_ENV_FILE) || File.exist?(PROC_SELF_CGROUP)
              'docker'
            end
          end

          def add_kubernetes_attributes(attrs)
            return unless ENV.fetch('KUBERNETES_SERVICE_HOST', nil)

            attrs[OpenTelemetry::SemanticConventions::Resource::K8S_POD_NAME] = ENV.fetch('HOSTNAME', nil)

            pod_uid = ENV.fetch('MY_POD_UID', nil)
            attrs[OpenTelemetry::SemanticConventions::Resource::K8S_POD_UID] = pod_uid if pod_uid

            ns = ENV.fetch('KUBERNETES_NAMESPACE', nil)
            attrs[OpenTelemetry::SemanticConventions::Resource::K8S_NAMESPACE_NAME] = ns if ns
          end

          def add_aws_ecs_attributes(attrs)
            return unless ENV.fetch('ECS_CONTAINER_METADATA_URI', nil) || ENV.fetch('ECS_CONTAINER_METADATA_URI_V4', nil)

            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'aws'
            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'aws_ecs'
          end

          def add_aws_lambda_attributes(attrs)
            lambda_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
            return unless lambda_name

            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'aws'
            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'aws_lambda'
            attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_NAME] = lambda_name

            version = ENV.fetch('AWS_LAMBDA_FUNCTION_VERSION', nil)
            attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION] = version if version

            arn = ENV.fetch('AWS_LAMBDA_FUNCTION_ARN', nil)
            attrs.merge!(parse_lambda_arn(arn)) if arn
          end

          def add_cloud_run_attributes(attrs)
            service = ENV.fetch('K_SERVICE', nil)
            return unless service

            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER] = 'gcp'
            attrs[OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM] = 'gcp_cloud_run'
            attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_NAME] = service

            revision = ENV.fetch('K_REVISION', nil)
            attrs[OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION] = revision if revision
          end

          # Returns true when the current OS is Linux.
          #
          # @return [Boolean]
          def linux?
            detect_os_type == 'linux'
          end

          # Detect the OS type string per OTel semconv os.type values.
          # Returns one of: "linux", "darwin", "windows", or the raw RbConfig string.
          #
          # @return [String]
          def detect_os_type
            raw = RbConfig::CONFIG['host_os'].to_s.downcase
            case raw
            when /linux/              then 'linux'
            when /darwin/             then 'darwin'
            when /mingw|mswin|cygwin/ then 'windows'
            else raw
            end
          end

          # Returns a stable machine-level identifier.
          # Reads /etc/machine-id (Linux systemd standard) or
          # /var/lib/dbus/machine-id as fallback. Returns nil on macOS/Windows.
          #
          # @return [String, nil]
          def host_id
            path = MACHINE_ID_PATHS.find { |machine_id_path| File.exist?(machine_id_path) }
            return nil unless path

            id = File.read(path).strip
            return id unless id.empty?

            nil
          rescue StandardError
            nil
          end

          # Parses a Lambda ARN and returns a hash of cloud.* resource attributes.
          #
          # @param arn [String] e.g. "arn:aws:lambda:us-east-1:123456789012:function:my-fn"
          # @return [Hash]
          def parse_lambda_arn(arn)
            return {} if arn.nil? || arn.empty?

            parts = arn.split(':')
            result = {}
            result[OpenTelemetry::SemanticConventions::Resource::CLOUD_REGION]     = parts[3] if parts[3] && !parts[3].empty?
            result[OpenTelemetry::SemanticConventions::Resource::CLOUD_ACCOUNT_ID] = parts[4] if parts[4] && !parts[4].empty?
            result[CLOUD_RESOURCE_ID]                                              = arn
            result
          rescue StandardError
            {}
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
            return nil unless File.exist?(PROC_SELF_CGROUP)

            line = File.readlines(PROC_SELF_CGROUP).find do |l|
              l.match?(%r{/docker/([a-f0-9]{64})})
            end

            return nil unless line

            match = line.match(%r{/docker/([a-f0-9]{64})})
            match[1]
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
