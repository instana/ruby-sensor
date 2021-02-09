# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Rack < Activator
      def can_instrument?
        defined?(::Rack)
      end

      def instrument
        require 'instana/instrumentation/rack'
      end
    end
  end
end
