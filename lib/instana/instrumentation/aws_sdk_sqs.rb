# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class SQS < Seahorse::Client::Plugin
      class Handler < Seahorse::Client::Handler
        SPAN_FORMING_OPERATIONS = [:send_message, :send_message_batch, :get_queue_url, :create_queue, :delete_message, :delete_message_batch].freeze

        def call(context)
          is_tracing = ::Instana.tracer.tracing?
          unless is_tracing && SPAN_FORMING_OPERATIONS.include?(context.operation_name)
            return @handler.call(context)
          end

          span_tags = tags_for(context.operation_name, context.params).compact

          ::Instana.tracer.trace(:sqs, {sqs: span_tags}) do |span|
            case context.operation_name
            when :send_message
              inject_instana_headers(span, context.params)
            when :send_message_batch
              context.params[:entries].each { |e| inject_instana_headers(span, e) }
            end

            response = @handler.call(context)

            span_tags[:queue] = response.queue_url if response.respond_to?(:queue_url)
            span.set_tags(sqs: span_tags)

            response
          end
        end

        private

        def inject_instana_headers(span, params)
          params[:message_attributes] ||= {}
          params[:message_attributes].merge!({
                                               "X_INSTANA_T" => {data_type: 'String', string_value: span.context.trace_id},
                                               "X_INSTANA_S" => {data_type: 'String', string_value: span.context.span_id},
                                               "X_INSTANA_L" => {data_type: 'String', string_value: span.context.level.to_s}
                                             })
        end

        def tags_for(operation_name, params)
          case operation_name
          when :create_queue
            {
              sort: 'exit',
              type: 'create.queue',
              queue: params[:queue_name]
            }
          when :get_queue_url
            {
              sort: 'exit',
              type: 'get.queue',
              queue: params[:queue_name]
            }
          when :send_message
            {
              sort: 'exit',
              type: 'single.sync',
              queue: params[:queue_url],
              group: params[:message_group_id]
            }
          when :send_message_batch
            {
              sort: 'exit',
              type: 'single.sync',
              queue: params[:queue_url],
              size: params[:entries].count
            }
          when :delete_message
            {
              sort: 'exit',
              type: 'delete.single.sync',
              queue: params[:queue_url]
            }
          when :delete_message_batch
            {
              sort: 'exit',
              type: 'delete.batch.sync',
              queue: params[:queue_url],
              size: params[:entries].count
            }
          else
            {}
          end
        end
      end

      def add_handlers(handlers, _config)
        handlers.add(Handler, step: :initialize)
      end
    end
  end
end
