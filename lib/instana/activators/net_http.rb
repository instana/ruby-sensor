# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class NetHTTP < Activator
      def can_instrument?
        defined?(::Net::HTTP) && ::Instana.config[:nethttp][:enabled]
      end

      def instrument
        require 'instana/instrumentation/net-http'

        ::Net::HTTP.prepend(::Instana::Instrumentation::NetHTTPInstrumentation)

        true
      end
    end
  end
end
