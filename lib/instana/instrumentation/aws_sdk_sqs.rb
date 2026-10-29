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

          span_tags = tags_for(context.operation_name, context.params).reject { |_, v| v.nil? }

          ::Instana.tracer.in_span(:sqs, attributes: {sqs: span_tags}) do |span|
            case context.operation_name
            when :send_message
              inject_instana_headers(span, context.params)
            when :send_message_batch
              context.params[:entries].each { |e| inject_instana_headers(span, e) }
            end

            response = @handler.call(context)

            span_tags[:queue] = response.queue_url if response.respond_to?(:queue_url)
            span.add_attributes(sqs: span_tags)

            response
          end
        end

        private

        def inject_instana_headers(span, params)
          params[:message_attributes] ||= {}
          span_context = span.context
          return unless span_context

          available_slots = 10 - params[:message_attributes].size

          extra = ::Instana::Util.aws_message_attributes_w3c(span_context)
          extra.merge!(::Instana::Util.aws_message_attributes_instana(span_context)) if available_slots >= 5

          extra.reject! { |_, v| v[:string_value].nil? || v[:string_value].empty? }
          params[:message_attributes].merge!(extra)
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
