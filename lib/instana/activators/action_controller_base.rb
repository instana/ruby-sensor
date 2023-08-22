# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class ActionControllerBase < Activator
      def can_instrument?
        defined?(::ActionController::Base) && Instana.config[:action_controller][:enabled]
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
