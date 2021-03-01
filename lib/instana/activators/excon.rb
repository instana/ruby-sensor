# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Excon < Activator
      def can_instrument?
        defined?(::Excon) && defined?(::Excon::Middleware::Base) && ::Excon.respond_to?(:defaults) && Instana.config[:excon][:enabled]
      end

      def instrument
        require 'instana/instrumentation/excon'

        ::Excon.defaults[:middlewares].unshift(::Instana::Instrumentation::Excon)

        true
      end
    end
  end
end
