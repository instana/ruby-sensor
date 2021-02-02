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
          ::Instana.tracer.log_entry(:'graphql.server')
          yield
        rescue Exception => e
          ::Instana.tracer.log_error(e)
          raise e
        ensure
          ::Instana.tracer.log_exit(:'graphql.server', {graphql: payload})
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
          [{object: parent.name, field: field.name}] + walk_fields(field, method)
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
