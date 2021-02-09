# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Sinatra < Activator
      def can_instrument?
        defined?(::Instana::Rack) && defined?(::Sinatra)
      end

      def instrument
        require 'instana/frameworks/sinatra'

        ::Sinatra::Base.use ::Instana::Rack
        ::Sinatra::Base.register ::Instana::SinatraPathTemplateExtractor

        true
      end
    end
  end
end
