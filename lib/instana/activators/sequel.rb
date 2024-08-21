# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Sequel < Activator
      def can_instrument?
        defined?(::Sequel::Database)
      end

      def instrument
        require 'instana/instrumentation/sequel'

        ::Sequel::Database
          .prepend(Instana::Instrumentation::Sequel)

        true
      end
    end
  end
end
