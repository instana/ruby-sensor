# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class AwsSdkLambda < Activator
      def can_instrument?
        defined?(::Aws::Lambda::Client) && ::Aws::Lambda::Client.respond_to?(:add_plugin)
      end

      def instrument
        require 'instana/instrumentation/aws_sdk_lambda'

        ::Aws::Lambda::Client.add_plugin(Instana::Instrumentation::Lambda)

        true
      end
    end
  end
end
