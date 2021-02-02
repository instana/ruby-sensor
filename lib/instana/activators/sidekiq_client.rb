module Instana
  module Activators
    class SidekiqClient < Activator
      def can_instrument?
        defined?(::Sidekiq) && ::Instana.config[:'sidekiq-client'][:enabled]
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
