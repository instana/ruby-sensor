# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class SidekiqWorker < Activator
      def can_instrument?
        defined?(::Sidekiq) && ::Sidekiq.respond_to?(:configure_server) && ::Instana.config[:'sidekiq-worker'][:enabled] &&
          Gem::Specification.find_by_name('sidekiq').version < Gem::Version.new('5.3')
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
