# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class ActiveJob < Activator
      def can_instrument?
        defined?(::ActiveJob::Base) &&
          Instana.config[:active_job][:enabled]
      end

      def instrument
        require 'instana/instrumentation/active_job'

        ::ActiveJob::Base
          .prepend(Instana::Instrumentation::ActiveJob)

        true
      end
    end
  end
end
