# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class Shoryuken
      def call(_worker_instance, _queue, sqs_message, _body, &block)
        sqs_tags = {
          sort: 'entry',
          queue: sqs_message.queue_url
        }

        context = incomming_context_from(sqs_message.message_attributes)
        ::Instana.tracer.start_or_continue_trace(:sqs, {sqs: sqs_tags}, context, &block)
      end

      private

      def incomming_context_from(attributes)
        trace_id = try(attributes, 'X_INSTANA_T', 'X_INSTANA_ST')
        span_id = try(attributes, 'X_INSTANA_S', 'X_INSTANA_SS')
        level = try(attributes, 'X_INSTANA_L', 'X_INSTANA_SL')

        {
          trace_id: trace_id,
          span_id: span_id,
          level: level
        }.compact
      end

      def try(attributes, *args)
        key = args.detect do |a|
          attributes && attributes[a] && attributes[a].respond_to?(:string_value)
        end

        attributes[key].string_value if attributes && key
      end
    end
  end
end
