# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActiveJob
      def self.prepended(target)
        target.around_enqueue do |job, block|
          tags = {
            activejob: {
              queue: job.queue_name,
              job: job.class.to_s,
              action: :enqueue,
              job_id: job.job_id
            }
          }

          ::Instana.tracer.in_span(:activejob, attributes: tags) do
            context = ::Instana.tracer.context
            job.arguments.append({
                                   instana_context: context ? context.to_hash : nil
                                 })

            block.call
          end
        end

        target.around_perform do |job, block|
          tags = {
            activejob: {
              queue: job.queue_name,
              job: job.class.to_s,
              action: :perform,
              job_id: job.job_id
            }
          }
          incoming_context = ::Instana::Instrumentation::ActiveJob.extract_context(job)

          Trace.with_span(OpenTelemetry::Trace.non_recording_span(incoming_context)) do
            ::Instana.tracer.in_span(:activejob, attributes: tags) do
              block.call
            end
          end
        end
      end

      def self.extract_context(job)
        # 1. From job arguments (Instana payload)
        if job.arguments.is_a?(Array) && job.arguments.last.is_a?(Hash) && job.arguments.last.key?(:instana_context)
          instana_context = job.arguments.last[:instana_context]
          job.arguments.pop
          return instana_context ? ::Instana::SpanContext.new(
            trace_id: instana_context[:trace_id],
            span_id: instana_context[:span_id],
            level: instana_context[:level] || 1
          ) : nil
        end

        # 2. From job.__otel_headers (if opentelemetry-instrumentation-active_job is active)
        if job.respond_to?(:__otel_headers) && job.__otel_headers.is_a?(Hash)
          headers = job.__otel_headers
          tp = headers['traceparent'] || headers[:traceparent]
          if tp
            ctx = parse_w3c_traceparent(tp, headers['tracestate'] || headers[:tracestate])
            return ctx if ctx
          end
        end

        nil
      end

      def self.parse_w3c_traceparent(traceparent, tracestate)
        ctx = ::Instana::Util.parse_w3c_trace_context(traceparent, tracestate)
        return nil unless ctx

        ::Instana::SpanContext.new(trace_id: ctx[:trace_id], span_id: ctx[:span_id], level: ctx[:level])
      end
    end
  end
end
