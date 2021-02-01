module Instana
  module Activators
    class GrpcServer < Activator
      def can_instrument?
        defined?(::GRPC::RpcDesc) && ::Instana.config[:grpc][:enabled]
      end

      def instrument
        require 'instana/instrumentation/grpc'

        ::GRPC::RpcDesc.prepend(::Instana::Instrumentation::GRPCServerInstrumentation)

        true
      end
    end
  end
end
