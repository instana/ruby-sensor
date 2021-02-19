# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class AwsDynamoDB < Activator
      def can_instrument?
        defined?(Aws::DynamoDB::Client)
      end

      def instrument
        require 'instana/instrumentation/aws_sdk_dynamodb'

        ::Aws::DynamoDB::Client.add_plugin(Instana::Instrumentation::DynamoDB)

        true
      end
    end
  end
end
