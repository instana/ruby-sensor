# frozen_string_literal: true

# (c) Copyright IBM Corp. 2025

require 'instana/span_filtering/configuration'
require 'instana/span_filtering/filter_rule'
require 'instana/span_filtering/condition'

module Instana
  # SpanFiltering module provides functionality to filter spans based on configured rules
  module SpanFiltering
    class << self
      attr_reader :configuration

      # Initialize the span filtering configuration
      # @return [Configuration] The span filtering configuration
      def initialize
        @configuration = Configuration.new
      end

      # Check if span filtering is deactivated
      # @return [Boolean] True if span filtering is deactivated
      def deactivated?
        @configuration&.deactivated || false
      end

      # Check if a span should be filtered out
      # @param span [Hash] The span to check
      # @return [Hash, nil] A result hash with filtered and suppression keys if filtered, nil if not filtered
      def filter_span(span)
        return nil if deactivated?
        return nil unless @configuration

        # Check include rules first (whitelist)
        # If we have include rules, only keep spans that match at least one include rule
        include_rules = @configuration.include_rules
        if include_rules.any? && include_rules.none? { |rule| rule.matches?(span) }
          return { filtered: true, suppression: false }
        end

        # Check exclude rules (blacklist)
        excluded_by = @configuration.exclude_rules.find { |rule| rule.matches?(span) }
        return { filtered: true, suppression: excluded_by.suppression } if excluded_by

        nil # Keep the span if no rules match
      end

      # Reset the configuration (mainly for testing)
      def reset
        @configuration = nil
      end
    end

    # Initialize on module load
    initialize
  end
end
