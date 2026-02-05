# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'yaml'

module Instana
  class Config
    def initialize(logger: ::Instana.logger, agent_host: ENV['INSTANA_AGENT_HOST'], agent_port: ENV['INSTANA_AGENT_PORT'])
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

    # Read stack trace configuration from YAML file, environment variables, or use defaults
    # Priority: YAML file > Environment variables > Agent discovery > Defaults
    def read_span_stack_config
      # Try to load from YAML file first
      yaml_config = read_span_stack_config_from_yaml

      if yaml_config
        @config[:back_trace] = yaml_config[:global]
        @config[:back_trace_technologies] = yaml_config[:technologies] || {}
      else
        # Fall back to environment variables or defaults
        read_span_stack_config_from_env
        @config[:back_trace_technologies] = {}
      end
    end

    # Read configuration from agent discovery response
    # This is called after agent discovery is complete
    # @param discovery [Hash] The discovery response from the agent
    def read_config_from_agent(discovery)
      return unless discovery.is_a?(Hash) && discovery['tracing']

      tracing_config = discovery['tracing']

      # Read stack trace configuration from agent if not already set from YAML or env
      read_span_stack_config_from_agent(tracing_config) if should_read_from_agent?(:back_trace)
      # Read span filtering configuration from agent
      ::Instana.span_filtering_config&.read_config_from_agent(discovery)
    rescue => e
      ::Instana.logger.warn("Failed to read configuration from agent: #{e.message}")
    end

    # Read stack trace configuration from agent discovery
    # @param tracing_config [Hash] The tracing configuration from discovery
    def read_span_stack_config_from_agent(tracing_config)
      return unless tracing_config['global']

      global_config = tracing_config['global']
      stack_trace_level = global_config['stack-trace']
      stack_trace_length = global_config['stack-trace-length']

      # Only update if at least one value is present
      if stack_trace_level || stack_trace_length
        @config[:back_trace] = {
          stack_trace_level: stack_trace_level || 'error',
          stack_trace_length: stack_trace_length ? stack_trace_length.to_i : 30,
          config_source: 'agent'
        }
      end

      # Read technology-specific configurations
      @config[:back_trace_technologies] = {}
      tracing_config.each do |key, value|
        next if key == 'global' || !value.is_a?(Hash)

        tech_stack_trace = value['stack-trace']
        tech_stack_trace_length = value['stack-trace-length']

        next unless tech_stack_trace || tech_stack_trace_length

        @config[:back_trace_technologies][key.to_sym] = {
          stack_trace_level: tech_stack_trace,
          stack_trace_length: tech_stack_trace_length ? tech_stack_trace_length.to_i : nil
        }.compact
      end
    end

    # Read stack trace configuration from YAML file
    # Returns hash with :global and :technologies keys or nil if not found
    def read_span_stack_config_from_yaml # rubocop:disable Metrics/CyclomaticComplexity
      config_path = ENV['INSTANA_CONFIG_PATH']
      return nil unless config_path && File.exist?(config_path)

      begin
        yaml_content = YAML.safe_load(File.read(config_path))

        # Support both "tracing" and "com.instana.tracing" as top-level keys
        tracing_config = yaml_content['tracing'] || yaml_content['com.instana.tracing']
        return nil unless tracing_config

        result = {}

        # Look for global stack trace configuration
        if tracing_config['global']
          global_config = tracing_config['global']
          stack_trace_level = global_config['stack-trace']
          stack_trace_length = global_config['stack-trace-length']

          if stack_trace_level || stack_trace_length
            result[:global] = {
              stack_trace_level: stack_trace_level || 'error',
              stack_trace_length: stack_trace_length ? stack_trace_length.to_i : 30,
              config_source: 'yaml'
            }
          end
        end

        # Look for technology-specific configurations
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

        result[:technologies] = technologies unless technologies.empty?

        result.empty? ? nil : result
      rescue => e
        ::Instana.logger.warn("Failed to load stack trace configuration from YAML: #{e.message}")
        nil
      end
    end

    # Read stack trace configuration from environment variables
    def read_span_stack_config_from_env
      stack_trace = ENV['INSTANA_STACK_TRACE']
      stack_trace_length = ENV['INSTANA_STACK_TRACE_LENGTH']
      config_source = stack_trace || stack_trace_length ? 'env' : 'default'
      @config[:back_trace] = {
        stack_trace_level: stack_trace || 'error',
        stack_trace_length: stack_trace_length ? stack_trace_length.to_i : 30,
        config_source: config_source
      }
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

  end
end

::Instana.config = ::Instana::Config.new
