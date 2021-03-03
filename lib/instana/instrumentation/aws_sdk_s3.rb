# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    class S3 < Seahorse::Client::Plugin
      class Handler < Seahorse::Client::Handler
        def call(context)
          s3_tags = {
            op: format_operation(context.operation_name),
            bucket: bucket_name_from(context),
            key: key_from_context(context)
          }.compact

          ::Instana.tracer.trace(:s3, {s3: s3_tags}) { @handler.call(context) }
        end

        private

        def bucket_name_from(context)
          context.params[:bucket] || 'Unknown'
        end

        def key_from_context(context)
          context.params[:key]
        end

        def format_operation(name)
          case name
          when :create_bucket
            'createBucket'
          when :delete_bucket
            'deleteBucket'
          when :delete_object
            'delete'
          when :get_object
            'get'
          when :head_object
            'metadata'
          when :list_objects
            'list'
          when :put_object
            'list'
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
