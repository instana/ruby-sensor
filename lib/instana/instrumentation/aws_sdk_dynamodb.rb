# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class DynamoDB < Seahorse::Client::Plugin
      class Handler < Seahorse::Client::Handler
        def call(context)
          dynamo_tags = {
            op: format_operation(context.operation_name),
            table: table_name_from(context)
          }

          ::Instana.tracer.trace(:dynamodb, {dynamodb: dynamo_tags}) { @handler.call(context) }
        end

        private

        def table_name_from(context)
          context.params[:table_name] || context.params[:global_table_name] || 'Unknown'
        end

        def format_operation(name)
          case name
          when :create_table
            'create'
          when :list_tables
            'list'
          when :get_item
            'get'
          when :put_item
            'put'
          when :update_item
            'update'
          when :delete_item
            'delete'
          else
            name.to_s
          end
        end

      end

      def add_handlers(handlers, _config)
        handlers.add(Handler, step: :initialize)
      end
    end
  end
end
