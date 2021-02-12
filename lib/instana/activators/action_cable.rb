# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class ActionCable < Activator
      def can_instrument?
        defined?(::ActionCable::Connection::Base) && defined?(::ActionCable::Channel::Base)
      end

      def instrument
        require 'instana/instrumentation/action_cable'

        ::ActionCable::Connection::Base
          .prepend(Instana::Instrumentation::ActionCableConnection)

        ::ActionCable::Channel::Base
          .prepend(Instana::Instrumentation::ActionCableChannel)

        true
      end
    end
  end
end
