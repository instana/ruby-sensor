module Instana
  module Activators
    class Rails < Activator
      def can_instrument?
        false
      end

      def instrument
        require 'instana/frameworks/rails'
      end
    end
  end
end
