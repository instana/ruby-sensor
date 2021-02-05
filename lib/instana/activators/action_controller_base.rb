module Instana
  module Activators
    class ActionControllerBase < Activator
      def can_instrument?
        defined?(::ActionController::Base)
      end

      def instrument
        require 'instana/instrumentation/action_controller'

        ::ActionController::Base
          .prepend(Instana::Instrumentation::ActionController)

        true
      end
    end
  end
end
