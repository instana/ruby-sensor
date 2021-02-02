module Instana
  module Activators
    class Excon < Activator
      def can_instrument?
        defined?(::Excon) && Instana.config[:excon][:enabled]
      end

      def instrument
        require 'instana/instrumentation/excon'

        ::Excon.defaults[:middlewares].unshift(::Instana::Instrumentation::Excon)

        true
      end
    end
  end
end
