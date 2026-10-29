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
            ::Instana.tracer.in_span(:sns, attributes: { sns: sns_tags }) do |_span|
              if ::Instana.tracer.tracing?
                inject_trace_attributes(context.params)
              end
              @handler.call(context)
            end
          elsif context.operation_name == :publish_batch
            ::Instana.tracer.in_span(:sns, attributes: { sns: sns_tags }) do |_span|
              if ::Instana.tracer.tracing?
                context.params[:publish_batch_request_entries]&.each do |entry|
                  inject_trace_attributes(entry)
                end
              end
              @handler.call(context)
            end
          else
            @handler.call(context)
          end
        end

        private

        def inject_trace_attributes(params)
          span_context = ::Instana.tracer.context
          return unless span_context

          params[:message_attributes] ||= {}
          available_slots = 10 - params[:message_attributes].size

          extra = ::Instana::Util.aws_message_attributes_w3c(span_context)
          extra.merge!(::Instana::Util.aws_message_attributes_instana(span_context)) if available_slots >= 5

          extra.reject! { |_, v| v[:string_value].nil? || v[:string_value].empty? }
          params[:message_attributes].merge!(extra)
        end
      end

      def add_handlers(handlers, _config)
        handlers.add(Handler, step: :initialize)
      end
    end
  end
end
