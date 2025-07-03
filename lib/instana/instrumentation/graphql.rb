# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class GraphqlTracing < GraphQL::Tracing::PlatformTracing
      self.platform_keys = {
        'lex' => 'lex.graphql',
        'parse' => 'parse.graphql',
        'validate' => 'validate.graphql',
        'analyze_query' => 'analyze.graphql',
        'analyze_multiplex' => 'analyze.graphql',
        'execute_multiplex' => 'execute.graphql',
        'execute_query' => 'execute.graphql',
        'execute_query_lazy' => 'execute.graphql',
      }

      def platform_trace(platform_key, key, data)
        return yield unless key == 'execute_query'
        operation = data[:query].selected_operation

        arguments = []
        fields = []

        operation.selections.each do |field|
          arguments.concat(walk_fields(field, :arguments))
          fields.concat(walk_fields(field, :selections))
        end

        payload = {
          operationName: data[:query].operation_name || 'anonymous',
          operationType: operation.operation_type,
          arguments: grouped_fields(arguments),
          fields: grouped_fields(fields),
        }

        begin
          span = ::Instana.tracer.start_span(:'graphql.server', attributes: {graphql: payload})
          yield
        rescue Exception => e
          span.record_exception(e)
          raise e
        ensure
          span.finish
        end
      end

      def platform_field_key(type, field)
        "#{type.graphql_name}.#{field.graphql_name}"
      end

      def platform_authorized_key(type)
        "#{type.graphql_name}.authorized.graphql"
      end

      def platform_resolve_type_key(type)
        "#{type.graphql_name}.resolve_type.graphql"
      end

      private

      def walk_fields(parent, method)
        return [] unless parent.respond_to?(method)

        parent.send(method).map do |field|
          # Certain types like GraphQL::Language::Nodes::InlineFragment
          # have no "name" instance variable defined,
          # in such case we use the class's name
          parent_name = if parent.instance_variable_defined?(:@name)
                          parent.name
                        else
                          parent.class.name.split('::').last
                        end
          field_name = if field.instance_variable_defined?(:@name)
                         field.name
                       else
                         field.class.name.split('::').last
                       end
          [{object: parent_name, field: field_name}] + walk_fields(field, method)
        end.flatten
      end

      def grouped_fields(fields)
        fields
          .group_by { |p| p[:object] }
          .map { |name, p| [name, p.map { |f| f[:field] }] }
          .to_h
      end
    end
  end
end
