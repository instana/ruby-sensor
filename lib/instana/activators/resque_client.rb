module Instana
  module Activators
    class ResqueClient < Activator
      def can_instrument?
        defined?(::Resque) &&
          ::Instana.config[:'resque-client'][:enabled]
      end

      def instrument
        require 'instana/instrumentation/resque'

        ::Resque.prepend(::Instana::Instrumentation::ResqueClient)

        true
      end
    end
  end
end
