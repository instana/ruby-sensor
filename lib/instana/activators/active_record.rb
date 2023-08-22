# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class ActiveRecord < Activator
      def can_instrument?
        defined?(::ActiveRecord::ConnectionAdapters::AbstractAdapter) &&
          Instana.config[:active_record][:enabled]
      end

      def instrument
        require 'instana/instrumentation/active_record'

        ::ActiveRecord::ConnectionAdapters::AbstractAdapter
          .prepend(Instana::Instrumentation::ActiveRecord)

        true
      end
    end
  end
end
