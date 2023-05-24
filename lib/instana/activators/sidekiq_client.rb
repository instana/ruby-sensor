# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class SidekiqClient < Activator
      def can_instrument?
        defined?(::Sidekiq) && ::Sidekiq.respond_to?(:configure_client) && ::Instana.config[:'sidekiq-client'][:enabled] &&
          Gem::Specification.find_by_name('sidekiq').version < Gem::Version.new('5.3')
      end

      def instrument
        require 'instana/instrumentation/sidekiq-client'

        ::Sidekiq.configure_client do |cfg|
          cfg.client_middleware do |chain|
            chain.add ::Instana::Instrumentation::SidekiqClient
          end
        end

        true
      end
    end
  end
end
