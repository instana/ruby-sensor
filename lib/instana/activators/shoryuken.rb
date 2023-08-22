# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Shoryuken < Activator
      def can_instrument?
        defined?(::Shoryuken) && ::Shoryuken.respond_to?(:configure_server) && ::Instana.config[:shoryuken][:enabled]
      end

      def instrument
        require 'instana/instrumentation/shoryuken'

        ::Shoryuken.configure_server do |config|
          config.server_middleware do |chain|
            chain.add ::Instana::Instrumentation::Shoryuken
          end
        end

        true
      end
    end
  end
end
