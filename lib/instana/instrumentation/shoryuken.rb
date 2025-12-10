# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class Shoryuken
      def call(_worker_instance, _queue, sqs_message, _body, &block)
        if sqs_message.is_a? Array
          return yield
        end

        sqs_tags = {
          sort: 'entry',
          queue: sqs_message.queue_url
        }

        context = incomming_context_from(sqs_message.message_attributes)
        instana_context = Instana::SpanContext.new(trace_id: context[:trace_id], span_id: context[:span_id], level: context[:level])
        Trace.with_span(OpenTelemetry::Trace.non_recording_span(instana_context)) do
          ::Instana.tracer.in_span(:sqs, attributes: {sqs: sqs_tags}, &block)
        end
      end

      private

      def incomming_context_from(attributes)
        trace_id = read_message_header(attributes, 'X_INSTANA_T')
        span_id = read_message_header(attributes, 'X_INSTANA_S')
        level = read_message_header(attributes, 'X_INSTANA_L')

        {
          trace_id: trace_id,
          span_id: span_id,
          level: level
        }.reject { |_, v| v.nil? }
      end

      def read_message_header(attributes, key)
        attributes[key].string_value if attributes && attributes[key] && attributes[key].respond_to?(:string_value)
      end
    end
  end
end
