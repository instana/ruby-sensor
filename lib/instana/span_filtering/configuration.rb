# (c) Copyright IBM Corp. 2025

require 'yaml'

module Instana
  module SpanFiltering
    # Configuration class for span filtering
    #
    # This class handles loading and managing span filtering rules from various sources:
    # - YAML configuration file (via INSTANA_CONFIG_PATH)
    # - Environment variables
    # - Agent discovery response
    # It supports both include and exclude rules with various matching strategies
    class Configuration
      attr_reader :include_rules, :exclude_rules, :deactivated

      TRACING_CONFIG_WARNING = 'Please use "tracing" instead of "com.instana.tracing" for local configuration file.'.freeze

      def initialize
        @include_rules = []
        @exclude_rules = []
        @deactivated = false
        load_configuration
      end

      # Load configuration from all available sources
      def load_configuration
        load_from_yaml
        load_from_env_vars unless rules_loaded?
        # Agent configuration will be loaded after discovery via read_config_from_agent
      end

      # Read configuration from agent discovery response
      # This is called from Config#read_config_from_agent after discovery is complete
      # @param discovery [Hash] The discovery response from the agent
      def read_config_from_agent(discovery)
        return if rules_loaded? # Don't override if already loaded from YAML or env

        process_discovery_config(discovery)
      rescue => e
        Instana.logger.warn("Failed to read span filtering configuration from agent: #{e.message}")
      end

      private

      # Process the discovery configuration
      def process_discovery_config(discovery)
        # Check if tracing configuration exists in the discovery response
        tracing_config = discovery['tracing']
        return unless tracing_config

        # Process filter configuration
        if tracing_config['filter']
          filter_config = tracing_config['filter']
          @deactivated = filter_config['deactivate'] == true

          # Process include rules
          process_rules(filter_config['include'], true) if filter_config['include']

          # Process exclude rules
          process_rules(filter_config['exclude'], false) if filter_config['exclude']
        end

        # Process disable configuration
        if tracing_config['disable']
          process_disable_config(tracing_config['disable'])
        end

        # Return true to indicate successful processing
        true
      rescue => e
        Instana.logger.warn("Failed to process discovery configuration: #{e.message}")
        false
      end

      # Check if the rules are already loaded
      def rules_loaded?
        @include_rules.any? || @exclude_rules.any?
      end

      # Load configuration from YAML file specified by INSTANA_CONFIG_PATH
      def load_from_yaml
        config_path = ENV['INSTANA_CONFIG_PATH']
        return unless config_path && File.exist?(config_path)

        begin
          yaml_content = YAML.safe_load(File.read(config_path))

          # Support both "tracing" and "com.instana.tracing" as top-level keys
          tracing_config = yaml_content['tracing'] || yaml_content['com.instana.tracing']
          ::Instana.logger.warn(TRACING_CONFIG_WARNING) if yaml_content.key?('com.instana.tracing')
          return unless tracing_config

          # Process filter configuration
          if tracing_config['filter']
            filter_config = tracing_config['filter']
            @deactivated = filter_config['deactivate'] == true

            # Process include rules
            process_rules(filter_config['include'], true) if filter_config['include']

            # Process exclude rules
            process_rules(filter_config['exclude'], false) if filter_config['exclude']
          end

          # Process disable configuration
          if tracing_config['disable']
            process_disable_config(tracing_config['disable'])
          end
        rescue => e
          Instana.logger.warn("Failed to load span filtering configuration from YAML: #{e.message}")
        end
      end

      # Load configuration from environment variables
      def load_from_env_vars
        ENV.each do |key, value|
          next unless key.start_with?('INSTANA_TRACING_FILTER_')

          parts = key.split('_')
          next unless parts.size >= 5

          policy = parts[3].downcase
          next unless ['include', 'exclude'].include?(policy)

          if parts[4] == 'ATTRIBUTES'
            process_env_attributes(policy, parts[4..].join('_'), value)
          elsif policy == 'exclude' && parts[4] == 'SUPPRESSION'
            process_env_suppression(parts[3..].join('_'), value)
          end
        end

        return unless !ENV["INSTANA_TRACING_DISABLE"].nil? && !%w[True true 1].include?(ENV["INSTANA_TRACING_DISABLE"])

        process_disable_config(ENV["INSTANA_TRACING_DISABLE"].split(','))
      end

      # Process rules from YAML configuration
      def process_rules(rules_config, is_include)
        rules_config.each do |rule_config|
          name = rule_config['name']
          suppression = is_include ? false : (rule_config['suppression'] != false) # Default true for exclude

          conditions = []
          rule_config['attributes'].each do |attr_config|
            key = attr_config['key']
            values = attr_config['values']
            match_type = attr_config['match_type'] || 'strict'

            conditions << Condition.new(key, values, match_type)
          end

          rule = FilterRule.new(name, suppression, conditions)
          is_include ? @include_rules << rule : @exclude_rules << rule
        end
      end

      # Process attributes from environment variables
      def process_env_attributes(policy, name, value)
        # Parse rules from environment variable format
        # Format: key;values;match_type|key;values;match_type
        rules = value.split('|')
        conditions = []

        rules.each do |rule|
          parts = rule.split(';')
          next unless parts.size >= 2

          key = parts[0]
          values = parts[1].split(',')
          match_type = parts[2] || 'strict'

          conditions << Condition.new(key, values, match_type)
        end

        rule_name = "EnvRule_#{name}"
        suppression = policy == 'exclude' # Default true for exclude

        rule = FilterRule.new(rule_name, suppression, conditions)
        policy == 'include' ? @include_rules << rule : @exclude_rules << rule
      end

      # Process suppression setting from environment variables
      def process_env_suppression(policy_name, value)
        # Find the corresponding rule and update its suppression value
        rule_index = policy_name.split('_')[1].to_i
        return if rule_index >= @exclude_rules.size

        suppression = %w[1 true True].include?(value)
        @exclude_rules[rule_index].suppression = suppression
      end

      # Process disable configuration from YAML or agent discovery
      # @param disable_config [Array] The disable configuration array
      def process_disable_config(disable_config)
        return unless disable_config.is_a?(Array)

        disable_config.each do |item|
          if item.is_a?(Hash)
            item.each do |key, value|
              if value == true
                update_instana_config_for_disabled_technology(key)
              end
            end
          elsif item.is_a?(String)
            update_instana_config_for_disabled_technology(item)
          end
        end
      end

      # Update Instana::Config for a disabled technology
      # @param technology [String] The technology to disable
      def update_instana_config_for_disabled_technology(technology)
        tech_sym = technology.to_sym

        case tech_sym
        when :redis
          ::Instana.config[:redis][:enabled] = false
        when :databases
          # If databases category is disabled, also disable redis
          ::Instana.config[:redis][:enabled] = false
        end
      end
    end
  end
end
