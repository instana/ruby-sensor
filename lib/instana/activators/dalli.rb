# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Dalli < Activator
      def can_instrument?
        defined?(::Dalli::Client) &&
          defined?(::Dalli::Server) &&
          Instana.config[:dalli][:enabled]
      end

      def instrument
        require 'instana/instrumentation/dalli'

        ::Dalli::Client.prepend ::Instana::Instrumentation::Dalli
        ::Dalli::Server.prepend ::Instana::Instrumentation::DalliServer

        true
      end
    end
  end
end
