# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Cuba < Activator
      def can_instrument?
        defined?(::Instana::Rack) && defined?(::Cuba) && Instana.config[:cuba][:enabled]
      end

      def instrument
        require 'instana/frameworks/cuba'

        ::Cuba.use ::Instana::Rack
        ::Cuba.prepend ::Instana::CubaPathTemplateExtractor

        true
      end
    end
  end
end
