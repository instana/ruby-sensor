module Instana
  module Activators
    class GrpcClient < Activator
      def can_instrument?
        defined?(::GRPC::ActiveCall) && ::Instana.config[:grpc][:enabled]
      end

      def instrument
        require 'instana/instrumentation/grpc'

        ::GRPC::ClientStub.prepend(::Instana::Instrumentation::GRPCCientInstrumentation)

        true
      end
    end
  end
end
