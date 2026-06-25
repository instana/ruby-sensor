# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'yaml'

module Instana
  class Config
    def initialize(logger: ::Instana.logger, agent_host: ENV['INSTANA_AGENT_HOST'], agent_port: ENV['INSTANA_AGENT_PORT']) # rubocop:disable Metrics/MethodLength
      @config = {}
      if agent_host
        logger.debug "Using custom agent host location specified in INSTANA_AGENT_HOST (#{ENV['INSTANA_AGENT_HOST']})"
        @config[:agent_host] = agent_host
      else
        @config[:agent_host] = '127.0.0.1'
      end
      if agent_port
        logger.debug "Using custom agent port specified in INSTANA_AGENT_PORT (#{ENV['INSTANA_AGENT_PORT']})"
        @config[:agent_port] = agent_port
      else
        @config[:agent_port] = 42699
      end

      # Enable/disable metrics globally or individually (default: all enabled)
      @config[:metrics] = { :enabled => true }
      @config[:metrics][:gc]     = { :enabled => true }
      @config[:metrics][:memory] = { :enabled => true }
      @config[:metrics][:thread] = { :enabled => true }

      # Enable/disable tracing (default: enabled)
      @config[:tracing] = { :enabled => true }

      # Enable/disable tracing exit spans as root spans
      @config[:allow_exit_as_root] = ENV['INSTANA_ALLOW_EXIT_AS_ROOT'] == '1'

      # Enable/Disable logging
      @config[:logging] = { :enabled => true }

      # Collector interval
      @config[:collector] = { :enabled => true, :interval => 1 }

      # EUM Related
      @config[:eum_api_key] = nil
      @config[:eum_baggage] = {}

      # In Ruby, backtrace collection is very expensive so it's
      # (unfortunately) disabled by default.  If you still want
      # backtraces, it can be enabled with this config option.
      # @config[:back_trace][:stack_trace_level] = all
      # @config[:back_trace] = { stack_trace_level: nil }
      read_span_stack_config

      # OTLP exporter configuration (default: disabled)
      @config[:otlp] = {
        enabled: false,
        endpoint: 'http://localhost:4318/v1/traces',
        timeout: 10_000,
        compression: nil,
        headers: {},
        certificate: nil,
        client_key: nil,
        client_certificate: nil,
        config_source: 'default'
      }
      read_otlp_config

      # By default, collected SQL will be sanitized to remove potentially sensitive bind params such as:
      #   > SELECT  "blocks".* FROM "blocks"  WHERE "blocks"."name" = "Mr. Smith"
      #
      # ...would be sanitized to be:
      #   > SELECT  "blocks".* FROM "blocks"  WHERE "blocks"."name" = ?
      #
      # This sanitization step can be disabled by setting the following value to false.
      # ::Instana.config[:sanitize_sql] = false
      @config[:sanitize_sql] = true

      # W3C Trace Context Support
      @config[:w3c_trace_correlation] = ENV['INSTANA_DISABLE_W3C_TRACE_CORRELATION'].nil?

      @config[:post_fork_proc] = proc { ::Instana.agent.spawn_background_thread }

      @config[:action_controller]  = { :enabled => true }
      @config[:action_view]        = { :enabled => true }
      @config[:active_record]      = { :enabled => true }
      @config[:bunny]              = { :enabled => true }
      @config[:dalli]              = { :enabled => true }
      @config[:excon]              = { :enabled => true }
      @config[:grpc]               = { :enabled => true }
      @config[:graphql]            = { :enabled => true }
      @config[:nethttp]            = { :enabled => true }
      @config[:redis]              = { :enabled => true }
      @config[:'resque-client']    = { :enabled => true, :propagate => true }
      @config[:'resque-worker']    = { :enabled => true, :'setup-fork' => true }
      @config[:'rest-client']      = { :enabled => true }
      @config[:sequel]             = { :enabled => true }
      @config[:'sidekiq-client']   = { :enabled => true }
      @config[:'sidekiq-worker']   = { :enabled => true }
    end

    def [](key)
      @config[key.to_sym]
    end

    def []=(key, value)
      @config[key.to_sym] = value
    end

    # Read stack trace configuration from environment variables, YAML file, or use defaults
    # Priority: Environment variables > YAML file > Agent discovery > Defaults
    def read_span_stack_config
      # Try environment variables first
      if ENV['INSTANA_STACK_TRACE'] || ENV['INSTANA_STACK_TRACE_LENGTH']
        read_span_stack_config_from_env
        @config[:back_trace_technologies] = {}
        return
      end

      # Try YAML file
      yaml_config = read_span_stack_config_from_yaml
      if yaml_config
        @config[:back_trace] = yaml_config[:global]
        @config[:back_trace_technologies] = yaml_config[:technologies] || {}
        return
      end

      # Use defaults
      apply_default_stack_trace_config
    end

    # Read configuration from agent discovery response
    # This is called after agent discovery is complete
    # @param discovery [Hash] The discovery response from the agent
    def read_config_from_agent(discovery)
      return unless discovery.is_a?(Hash) && discovery['tracing']

      tracing_config = discovery['tracing']

      # Read stack trace configuration from agent if not already set from YAML or env
      read_span_stack_config_from_agent(tracing_config) if should_read_from_agent?(:back_trace)
      # Read OTLP configuration from agent if not already set from YAML or env
      read_otlp_config_from_agent(tracing_config) if should_read_from_agent?(:otlp)
      # Read span filtering configuration from agent
      ::Instana.span_filtering_config&.read_config_from_agent(discovery)
    rescue => e
      ::Instana.logger.warn("Failed to read configuration from agent: #{e.message}")
    end

    # Read stack trace configuration from agent discovery
    # @param tracing_config [Hash] The tracing configuration from discovery
    def read_span_stack_config_from_agent(tracing_config)
      return unless tracing_config['global']

      global_config = parse_global_stack_trace_config(tracing_config['global'], 'agent')
      @config[:back_trace] = global_config if global_config

      # Read technology-specific configurations
      @config[:back_trace_technologies] = parse_technology_configs(tracing_config)
    end

    # Read stack trace configuration from YAML file
    # Returns hash with :global and :technologies keys or nil if not found
    def read_span_stack_config_from_yaml
      config_path = ENV['INSTANA_CONFIG_PATH']
      return nil unless config_path && File.exist?(config_path)

      begin
        yaml_content = YAML.safe_load(File.read(config_path))

        # Support both "tracing" and "com.instana.tracing" as top-level keys
        if yaml_content['com.instana.tracing']
          ::Instana.logger.warn('Please use "tracing" instead of "com.instana.tracing"')
        end
        tracing_config = yaml_content['tracing'] || yaml_content['com.instana.tracing']
        return nil unless tracing_config

        result = {}

        # Look for global stack trace configuration
        if tracing_config['global']
          global_config = parse_global_stack_trace_config(tracing_config['global'], 'yaml')
          result[:global] = global_config if global_config
        end

        # Look for technology-specific configurations
        technologies = parse_technology_configs(tracing_config)
        result[:technologies] = technologies unless technologies.empty?

        result.empty? ? nil : result
      rescue => e
        ::Instana.logger.warn("Failed to load stack trace configuration from YAML: #{e.message}")
        nil
      end
    end

    # Read stack trace configuration from environment variables
    def read_span_stack_config_from_env
      @config[:back_trace] = {
        stack_trace_level: ENV['INSTANA_STACK_TRACE'] || 'error',
        stack_trace_length: ENV['INSTANA_STACK_TRACE_LENGTH']&.to_i || 30,
        config_source: 'env'
      }
    end

    # Apply default stack trace configuration
    def apply_default_stack_trace_config
      @config[:back_trace] = {
        stack_trace_level: 'error',
        stack_trace_length: 30,
        config_source: 'default'
      }
      @config[:back_trace_technologies] = {}
    end

    # Check if we should read configuration from agent
    # Returns true if config was not set from YAML or environment variables
    def should_read_from_agent?(config_key)
      return true unless @config[config_key]

      source = @config[config_key][:config_source]
      source.nil? || source == 'default'
    end

    # Get stack trace configuration for a specific technology
    # Falls back to global configuration if technology-specific config is not found
    # @param technology [Symbol] The technology name (e.g., :excon, :kafka, :activerecord)
    # @return [Hash] Configuration hash with :stack_trace_level and :stack_trace_length
    def get_stack_trace_config(technology)
      tech_config = @config[:back_trace_technologies]&.[](technology)
      global_config = @config[:back_trace] || {}

      {
        stack_trace_level: tech_config&.[](:stack_trace_level) || global_config[:stack_trace_level] || 'error',
        stack_trace_length: tech_config&.[](:stack_trace_length) || global_config[:stack_trace_length] || 30
      }
    end

    # Read OTLP configuration from agent discovery
    # @param tracing_config [Hash] The tracing configuration from discovery
    def read_otlp_config_from_agent(tracing_config)
      otlp_config = tracing_config['otlp']
      return unless otlp_config.is_a?(Hash)

      @config[:otlp][:enabled]            = truthy?(otlp_config['enabled'])         unless otlp_config['enabled'].nil?
      @config[:otlp][:endpoint]           = otlp_config['endpoint']                 if otlp_config['endpoint']
      @config[:otlp][:timeout]            = otlp_config['timeout'].to_i             if otlp_config['timeout']
      @config[:otlp][:compression]        = otlp_config['compression']              if otlp_config['compression']
      @config[:otlp][:headers]            = otlp_config['headers']                  if otlp_config['headers'].is_a?(Hash)
      @config[:otlp][:certificate]        = otlp_config['certificate']              if otlp_config['certificate']
      @config[:otlp][:client_key]         = otlp_config['client_key']               if otlp_config['client_key']
      @config[:otlp][:client_certificate] = otlp_config['client_certificate']       if otlp_config['client_certificate']
      @config[:otlp][:config_source]      = 'agent'
    end

    private

    # Read OTLP configuration — precedence: YAML > env vars > defaults (agent handled separately)
    def read_otlp_config
      # Try YAML first
      yaml_otlp = parse_otlp_config_from_yaml
      if yaml_otlp
        @config[:otlp].merge!(yaml_otlp)
        @config[:otlp][:config_source] = 'yaml'
        return
      end

      # Try environment variables
      env_otlp = parse_otlp_config_from_env
      if env_otlp
        @config[:otlp].merge!(env_otlp)
        @config[:otlp][:config_source] = 'env'
      end
      # Otherwise leave defaults ('default' config_source), agent can update later
    end

    # Parse OTLP config from YAML file at INSTANA_CONFIG_PATH under tracing.otlp
    # @return [Hash, nil] merged OTLP settings or nil if not found
    def parse_otlp_config_from_yaml
      config_path = ENV.fetch('INSTANA_CONFIG_PATH', nil)
      return nil unless config_path && File.exist?(config_path)

      begin
        yaml_content = YAML.safe_load(File.read(config_path))
        tracing_config = yaml_content['tracing'] || yaml_content['com.instana.tracing']
        return nil unless tracing_config

        otlp_yaml = tracing_config['otlp']
        return nil unless otlp_yaml.is_a?(Hash)

        result = {}
        result[:enabled]            = truthy?(otlp_yaml['enabled'])            unless otlp_yaml['enabled'].nil?
        result[:endpoint]           = otlp_yaml['endpoint']                    if otlp_yaml['endpoint']
        result[:timeout]            = otlp_yaml['timeout'].to_i                if otlp_yaml['timeout']
        result[:compression]        = otlp_yaml['compression']                 if otlp_yaml['compression']
        result[:headers]            = otlp_yaml['headers']                     if otlp_yaml['headers'].is_a?(Hash)
        result[:certificate]        = otlp_yaml['certificate']                 if otlp_yaml['certificate']
        result[:client_key]         = otlp_yaml['client_key']                  if otlp_yaml['client_key']
        result[:client_certificate] = otlp_yaml['client_certificate']          if otlp_yaml['client_certificate']

        result.empty? ? nil : result
      rescue => e
        ::Instana.logger.warn("Failed to load OTLP configuration from YAML: #{e.message}")
        nil
      end
    end

    # Parse OTLP config from environment variables
    # @return [Hash, nil] merged OTLP settings or nil if no relevant env vars are set
    def parse_otlp_config_from_env
      raw = otlp_env_vars
      return nil if raw.values.all?(&:nil?)

      result = {}
      result[:enabled]            = truthy?(raw[:enabled_raw])              unless raw[:enabled_raw].nil?
      result[:endpoint]           = raw[:endpoint]                          if raw[:endpoint]
      result[:timeout]            = raw[:timeout_raw].to_i                  if raw[:timeout_raw]
      result[:compression]        = raw[:compression]                       if raw[:compression]
      result[:headers]            = parse_otlp_headers(raw[:headers_raw])   if raw[:headers_raw]
      result[:certificate]        = raw[:certificate]                       if raw[:certificate]
      result[:client_key]         = raw[:client_key]                        if raw[:client_key]
      result[:client_certificate] = raw[:client_cert]                       if raw[:client_cert]
      result
    end

    # Collect raw OTLP-related environment variable values into a single hash
    # @return [Hash]
    def otlp_env_vars
      {
        enabled_raw: ENV.fetch('INSTANA_TRACING_OTLP_ENABLED', nil),
        endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', nil) || ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil),
        timeout_raw: ENV.fetch('OTEL_EXPORTER_OTLP_TIMEOUT', nil),
        compression: ENV.fetch('OTEL_EXPORTER_OTLP_COMPRESSION', nil),
        headers_raw: ENV.fetch('OTEL_EXPORTER_OTLP_HEADERS', nil),
        certificate: ENV.fetch('OTEL_EXPORTER_OTLP_CERTIFICATE', nil),
        client_key: ENV.fetch('OTEL_EXPORTER_OTLP_CLIENT_KEY', nil),
        client_cert: ENV.fetch('OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE', nil)
      }
    end

    # Parse OTEL_EXPORTER_OTLP_HEADERS value (comma-separated key=value pairs) into a Hash
    # @param headers_str [String] e.g. "api-key=secret,x-tenant=tenant1"
    # @return [Hash]
    def parse_otlp_headers(headers_str)
      return {} unless headers_str

      headers_str.split(',').each_with_object({}) do |pair, hash|
        key, value = pair.split('=', 2)
        hash[key.strip] = value&.strip if key
      end
    end

    # Normalise a truthy string value to a boolean
    def truthy?(value)
      %w[true 1 yes].include?(value.to_s.downcase)
    end

    # Parse global stack trace configuration from a config hash
    # @param global_config [Hash] The global configuration hash
    # @param config_source [String] The source of the configuration ('yaml', 'agent', etc.)
    # @return [Hash, nil] Parsed configuration or nil if no valid config found
    def parse_global_stack_trace_config(global_config, config_source)
      return nil unless global_config.is_a?(Hash)

      stack_trace_level = global_config['stack-trace']
      stack_trace_length = global_config['stack-trace-length']

      # Only return config if at least one value is present
      return nil unless stack_trace_level || stack_trace_length

      {
        stack_trace_level: stack_trace_level || 'error',
        stack_trace_length: stack_trace_length ? stack_trace_length.to_i : 30,
        config_source: config_source
      }
    end

    # Parse technology-specific stack trace configurations from tracing config
    # @param tracing_config [Hash] The tracing configuration hash
    # @return [Hash] Technology-specific configurations
    def parse_technology_configs(tracing_config)
      technologies = {}
      tracing_config.each do |key, value|
        next if key == 'global' || !value.is_a?(Hash)

        tech_stack_trace = value['stack-trace']
        tech_stack_trace_length = value['stack-trace-length']

        next unless tech_stack_trace || tech_stack_trace_length

        technologies[key.to_sym] = {
          stack_trace_level: tech_stack_trace,
          stack_trace_length: tech_stack_trace_length ? tech_stack_trace_length.to_i : nil
        }.compact
      end
      technologies
    end

  end
end

::Instana.config = ::Instana::Config.new
