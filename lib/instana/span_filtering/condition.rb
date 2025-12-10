# (c) Copyright IBM Corp. 2025

module Instana
  module SpanFiltering
    # Represents a condition for filtering spans
    #
    # A condition consists of:
    # - key: The attribute to match against (category, kind, type, or span attribute)
    # - values: List of values to match against (OR logic between values)
    # - match_type: String matching strategy (strict, startswith, endswith, contains)
    class Condition
      attr_reader :key, :values, :match_type

      def initialize(key, values, match_type = 'strict')
        @key = key
        @values = Array(values)
        @match_type = match_type
      end

      # Check if a span matches this condition
      # @param span [Hash] The span to check
      # @return [Boolean] True if the span matches any of the values
      def matches?(span)
        attribute_value = extract_attribute(span, @key)
        return false if attribute_value.nil?

        @values.any? { |value| matches_value?(attribute_value, value) }
      end

      private

      # Extract an attribute from a span
      # @param span [Hash] The span to extract from
      # @param key [String] The key to extract
      # @return [Object, nil] The attribute value or nil if not found
      def extract_attribute(span, key)
        case key
        when 'category'
          # Map to appropriate span attribute for category
          determine_category(span)
        when 'kind'
          # Map to appropriate span attribute for kind
          span[:k] || span['k']
        when 'type'
          # Map to appropriate span attribute for type
          span[:n] || span['n']
        else
          # Handle nested attributes with dot notation
          extract_nested_attribute(span[:data] || span['data'], key)
        end
      end

      # Determine the category of a span based on its properties
      # @param span [Hash] The span to categorize
      # @return [String, nil] The category or nil if not determinable
      def determine_category(span)
        data = span[:data] || span['data']
        return nil unless data

        if data[:http] || data['http']
          'protocols'
        elsif data[:redis] || data[:mysql] || data[:pg] || data[:db]
          'databases'
        elsif data[:sqs] || data[:sns] || data[:mq]
          'messaging'
        elsif (span[:n] || span['n'])&.start_with?('log.')
          'logging'
        end
      end

      # Extract a nested attribute using dot notation
      # @param data [Hash] The data hash to extract from
      # @param key [String] The key in dot notation
      # @return [Object, nil] The attribute value or nil if not found
      def extract_nested_attribute(data, key)
        return nil unless data

        parts = key.split('.')
        current = data

        parts.each do |part|
          # Try symbol key first, then string key
          if current.key?(part.to_sym)
            current = current[part.to_sym]
          elsif current.key?(part)
            current = current[part]
          else
            return nil # Key not found
          end

          # Only return nil if the value is actually nil, not for false values
        end

        current
      end

      # Check if an attribute value matches a condition value
      # @param attribute_value [Object] The attribute value
      # @param condition_value [String] The condition value
      # @return [Boolean] True if the attribute value matches the condition value
      def matches_value?(attribute_value, condition_value)
        # Handle wildcard
        return true if condition_value == '*'

        # Direct comparison first - this should handle boolean values correctly
        return true if attribute_value == condition_value

        # For strict matching with type conversion
        if @match_type == 'strict'
          # Convert to strings and compare
          attribute_str = attribute_value.to_s
          condition_str = condition_value.to_s
          return attribute_str == condition_str
        end

        # For other match types, convert both to strings
        attribute_str = attribute_value.to_s
        condition_str = condition_value.to_s

        case @match_type
        when 'startswith'
          attribute_str.start_with?(condition_str)
        when 'endswith'
          attribute_str.end_with?(condition_str)
        when 'contains'
          attribute_str.include?(condition_str)
        else
          # Default to strict matching
          attribute_str == condition_str
        end
      end
    end
  end
end
