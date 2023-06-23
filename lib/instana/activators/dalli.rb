# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Dalli < Activator
      def can_instrument?
        defined?(::Dalli::Protocol::Base || defined?(::Dalli::Server)) &&
          defined?(::Dalli::Client) &&
          Instana.config[:dalli][:enabled]
      end

      def instrument
        require 'instana/instrumentation/dalli'
        dalli_version = Gem::Specification.find_by_name('dalli').version
        ::Dalli::Client.prepend ::Instana::Instrumentation::Dalli
        if dalli_version < Gem::Version.new('3.0')
          ::Dalli::Server.prepend ::Instana::Instrumentation::DalliRequestHandler
        elsif dalli_version >= Gem::Version.new('3.0') && dalli_version < Gem::Version.new('3.1.3')
          ::Dalli::Protocol::Binary.prepend ::Instana::Instrumentation::DalliRequestHandler
        else
          ::Dalli::Protocol::Base.prepend ::Instana::Instrumentation::DalliRequestHandler
        end

        true
      end
    end
  end
end
