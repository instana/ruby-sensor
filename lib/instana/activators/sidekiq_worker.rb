module Instana
  module Activators
    class SidekiqWorker < Activator
      def can_instrument?
        defined?(::Sidekiq) && ::Instana.config[:'sidekiq-worker'][:enabled]
      end

      def instrument
        require 'instana/instrumentation/sidekiq-worker'

        ::Sidekiq.configure_server do |cfg|
          cfg.server_middleware do |chain|
            chain.add ::Instana::Instrumentation::SidekiqWorker
          end
        end

        true
      end
    end
  end
end
