# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActionCableConnection
      def instana_trace_context
        @instana_trace_context
      end

      def process
        # Wrapped in non_recording_span by the channel callbacks below, so it
        # must be a SpanContext.
        @instana_trace_context ||= if ::Instana.tracer.tracing?
                                     ::Instana.tracer.current_span.context
                                   else
                                     OpenTelemetry::Trace::SpanContext::INVALID
                                   end
        super
      end
    end

    module ActionCableChannel
      def transmit(data, via: nil)
        rpc_tags = {
          service: ::Instana::Util.get_app_name,
          rpc: {
            flavor: :actioncable,
            call: self.class.to_s,
            call_type: :transmit,
            host: Socket.gethostname
          }
        }

        context = connection.instana_trace_context
        Trace.with_span(OpenTelemetry::Trace.non_recording_span(context)) do
          ::Instana.tracer.in_span(:'rpc-server', attributes: rpc_tags) do
            super(data, via: via)
          end
        end
      end

      def dispatch_action(action, data)
        rpc_tags = {
          service: ::Instana::Util.get_app_name,
          rpc: {
            flavor: :actioncable,
            call: "#{self.class}##{action}",
            call_type: :action,
            host: Socket.gethostname
          }
        }

        context = connection.instana_trace_context
        Trace.with_span(OpenTelemetry::Trace.non_recording_span(context)) do
          ::Instana.tracer.in_span(:'rpc-server', attributes: rpc_tags) do
            super(action, data)
          end
        end
      end
    end
  end
end
