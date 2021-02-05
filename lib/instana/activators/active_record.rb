module Instana
  module Activators
    class ActiveRecord < Activator
      def can_instrument?
        defined?(::ActiveRecord::ConnectionAdapters::AbstractAdapter)
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
