# frozen_string_literal: true

# (c) Copyright IBM Corp. 2025

module Instana
  module SpanFiltering
    # Represents a filtering rule for spans
    #
    # A rule consists of:
    # - name: A human-readable identifier for the rule
    # - suppression: Whether child spans should be suppressed (only for exclude rules)
    # - conditions: A list of conditions that must all be satisfied (AND logic)
    class FilterRule
      attr_reader :name
      attr_accessor :suppression, :conditions

      def initialize(name, suppression, conditions)
        @name = name
        @suppression = suppression
        @conditions = conditions
      end

      # Check if a span matches this rule
      # @param span [Hash] The span to check
      # @return [Boolean] True if the span matches all conditions
      def matches?(span)
        @conditions.all? { |condition| condition.matches?(span) }
      end
    end
  end
end
