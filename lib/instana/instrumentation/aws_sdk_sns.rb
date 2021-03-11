# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class SNS < Seahorse::Client::Plugin
      class Handler < Seahorse::Client::Handler
        def call(context)
          sns_tags = {
            topic: context.params[:topic_arn],
            target: context.params[:target_arn],
            phone: context.params[:phone_number],
            subject: context.params[:subject]
          }.compact

          if context.operation_name == :publish
            ::Instana.tracer.trace(:sns, {sns: sns_tags}) { @handler.call(context) }
          else
            @handler.call(context)
          end
        end
      end

      def add_handlers(handlers, _config)
        handlers.add(Handler, step: :initialize)
      end
    end
  end
end
