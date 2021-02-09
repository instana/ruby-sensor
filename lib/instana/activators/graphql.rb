# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Graphql < Activator
      def can_instrument?
        defined?(::GraphQL::Schema) &&
          defined?(GraphQL::Tracing::PlatformTracing) &&
          Instana.config[:graphql][:enabled]
      end

      def instrument
        require 'instana/instrumentation/graphql'

        ::GraphQL::Schema.use(::Instana::Instrumentation::GraphqlTracing)

        true
      end
    end
  end
end
