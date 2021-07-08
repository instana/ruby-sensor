# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class ActionMailer < Activator
      def can_instrument?
        defined?(::ActionMailer::Base) && defined?(ActiveSupport::Executor)
      end

      def instrument
        require 'instana/instrumentation/action_mailer'

        ::ActionMailer::Base
          .singleton_class
          .prepend(Instana::Instrumentation::ActionMailer)

        true
      end
    end
  end
end
