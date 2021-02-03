module Instana
  module Activators
    class ActionControllerAPI < Activator
      def can_instrument?
        defined?(::ActionController::API)
      end

      def instrument
        require 'instana/instrumentation/action_controller'

        ::ActionController::API
          .prepend(Instana::Instrumentation::ActionController)

        true
      end
    end
  end
end
