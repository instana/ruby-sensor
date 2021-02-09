# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Rails < Activator
      def can_instrument?
        defined?(::Instana::Rack) &&
          defined?(::Rails) &&
          defined?(::Rails::VERSION)
      end

      def instrument
        require 'instana/frameworks/rails'
      end
    end
  end
end
