# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class RestClient < Activator
      def can_instrument?
        defined?(::RestClient::Request) && ::Instana.config[:'rest-client'][:enabled]
      end

      def instrument
        require 'instana/instrumentation/rest-client'

        ::RestClient::Request.prepend ::Instana::Instrumentation::RestClientRequest

        true
      end
    end
  end
end
