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
          }.reject { |_, v| v.nil? }

          if context.operation_name == :publish
            ::Instana.tracer.in_span(:sns, attributes: {sns: sns_tags}) do |_span|
              if ::Instana.tracer.tracing?
                span_context = ::Instana.tracer.context
                context.params[:message_attributes] ||= {}
                context.params[:message_attributes].merge!(
                  'X_INSTANA_T' => { data_type: 'String', string_value: span_context.trace_id_header },
                  'X_INSTANA_S' => { data_type: 'String', string_value: span_context.span_id_header },
                  'X_INSTANA_L' => { data_type: 'String', string_value: span_context.level.to_s }
                )
              end
              @handler.call(context)
            end
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
