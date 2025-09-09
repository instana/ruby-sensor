# (c) Copyright IBM Corp. 2025

require 'yaml'

module Instana
  module SpanFiltering
    # Configuration class for span filtering
    #
    # This class handles loading and managing span filtering rules from various sources:
    # - YAML configuration file (via INSTANA_CONFIG_PATH)
    # - Environment variables
    #
    # It supports both include and exclude rules with various matching strategies
    class Configuration
      attr_reader :include_rules, :exclude_rules, :deactivated

      def initialize
        @include_rules = []
        @exclude_rules = []
        @deactivated = false
        load_configuration
      end

      # Load configuration from all available sources
      def load_configuration
        load_from_yaml
        load_from_env_vars
      end

      private

      # Load configuration from YAML file specified by INSTANA_CONFIG_PATH
      def load_from_yaml
        config_path = ENV['INSTANA_CONFIG_PATH']
        return unless config_path && File.exist?(config_path)

        begin
          yaml_content = YAML.safe_load(File.read(config_path))

          # Support both "tracing" and "com.instana.tracing" as top-level keys
          tracing_config = yaml_content['tracing'] || yaml_content['com.instana.tracing']
          return unless tracing_config && tracing_config['filter']

          filter_config = tracing_config['filter']
          @deactivated = filter_config['deactivate'] == true

          # Process include rules
          process_rules(filter_config['include'], true) if filter_config['include']

          # Process exclude rules
          process_rules(filter_config['exclude'], false) if filter_config['exclude']
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
            process_env_attributes(policy, parts[4..-1].join('_'), value)
          elsif policy == 'exclude' && parts[4] == 'SUPPRESSION'
            process_env_suppression(parts[3..-1].join('_'), value)
          end
        end
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

        suppression = ['1', 'true', 'True'].include?(value)
        @exclude_rules[rule_index].suppression = suppression
      end
    end
  end
end
