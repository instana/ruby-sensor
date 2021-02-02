module Instana
  module Activators
    class Cuba < Activator
      def can_instrument?
        defined?(::Instana::Rack) && defined?(::Cuba)
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
