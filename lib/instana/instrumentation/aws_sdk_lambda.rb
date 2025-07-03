# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021
require 'base64'

module Instana
  module Instrumentation
    class Lambda < Seahorse::Client::Plugin
      class Handler < Seahorse::Client::Handler
        def call(context)
          return @handler.call(context) unless [:invoke_async, :invoke].include?(context.operation_name)

          if context.params[:client_context].nil? && ::Instana.tracer.tracing? && context.operation_name == :invoke
            span_context = ::Instana.tracer.context
            payload = {
              'X-INSTANA-T' => span_context.trace_id,
              'X-INSTANA-S' => span_context.span_id,
              'X-INSTANA-L' => span_context.level.to_s
            }

            context.params[:client_context] = Base64.strict_encode64(JSON.dump(payload))
          end

          tags = {
            function: context.params[:function_name],
            type: context.params[:invocation_type]
          }.reject { |_, v| v.nil? }

          ::Instana.tracer.in_span(:"aws.lambda.invoke", attributes: {aws: {lambda: {invoke: tags}}}) do
            response = @handler.call(context)
            if response.respond_to? :status_code
              ::Instana.tracer.log_info(:http => {:status => response.status_code })
            end
            response
          end
        end
      end

      def add_handlers(handlers, _config)
        handlers.add(Handler, step: :initialize)
      end
    end
  end
end
