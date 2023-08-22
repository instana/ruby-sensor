# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class AwsSdkSns < Activator
      def can_instrument?
        defined?(::Aws::SNS::Client) && ::Aws::SNS::Client.respond_to?(:add_plugin) && Instana.config[:aws_sns][:enabled]
      end

      def instrument
        require 'instana/instrumentation/aws_sdk_sns'

        ::Aws::SNS::Client.add_plugin(Instana::Instrumentation::SNS)

        true
      end
    end
  end
end
