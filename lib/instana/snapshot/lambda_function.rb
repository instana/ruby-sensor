module Instana
  module Backend
    # @since 1.198.0
    class LambdaFunction
      ID = "com.instana.plugin.aws.lambda".freeze

      def entity_id
        Thread.current[:instana_function_arn]
      end

      def data
        {}
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      def source
        {

        }
      end

      def host_name
        entity_id
      end


    end
  end
end
