# (c) Copyright IBM Corp. 2025

module Instana
  module Activators
    class Bunny < Activator
      def can_instrument?
        defined?(::Bunny) &&
          defined?(::Bunny::Queue) &&
          defined?(::Bunny::Exchange) &&
          ::Instana.config[:bunny][:enabled]
      end

      def instrument
        require 'instana/instrumentation/bunny'

        ::Bunny::Exchange.prepend(::Instana::Instrumentation::BunnyProducer)
        ::Bunny::Queue.prepend(::Instana::Instrumentation::BunnyConsumer)

        true
      end
    end
  end
end
