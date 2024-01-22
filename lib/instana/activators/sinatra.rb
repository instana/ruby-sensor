# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Sinatra < Activator
      def can_instrument?
        defined?(::Instana::Rack) && defined?(::Sinatra) && defined?(::Sinatra::Base) && !::Sinatra::Base.middleware.nil?
      end

      def instrument
        require 'instana/frameworks/sinatra'

        ::Sinatra::Base.use ::Instana::Rack
        unless ::Sinatra::Base.respond_to?(:mustermann_opts)
          ::Sinatra::Base.set :mustermann_opts, {}
        end
        ::Sinatra::Base.register ::Instana::SinatraPathTemplateExtractor

        true
      end
    end
  end
end
