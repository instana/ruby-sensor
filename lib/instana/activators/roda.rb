module Instana
  module Activators
    class Roda < Activator
      def can_instrument?
        defined?(::Instana::Rack) && defined?(::Roda)
      end

      def instrument
        require 'instana/frameworks/roda'

        ::Roda.use ::Instana::Rack
        ::Roda.plugin ::Instana::RodaPathTemplateExtractor

        true
      end
    end
  end
end
