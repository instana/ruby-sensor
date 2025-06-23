# (c) Copyright IBM Corp. 2025

module Instana
  module Trace
    module Samplers
      class Result
        EMPTY_HASH = {}.freeze
        attr_reader :tracestate, :attributes

        def initialize(decision:, tracestate:, attributes: nil)
          @decision = decision
          @attributes = attributes.freeze || EMPTY_HASH
          @tracestate = tracestate
        end

        # Returns true if this span should be sampled.
        #
        # @return FALSE always
        def sampled?
          false
        end

        # Returns true if this span should record events, attributes, status, etc.
        #
        # returns TRUE always
        def recording?
          true
        end
      end
    end
  end
end
