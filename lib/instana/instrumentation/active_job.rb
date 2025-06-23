# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021
module OpenTelemetry
  module Trace
    module Propagation
      module TraceContext
        # A TraceParent is an implementation of the W3C trace context specification
        # https://www.w3.org/TR/trace-context/
        # {Trace::SpanContext}
        class TraceParent
          REGEXP = /^(?<version>[A-Fa-f0-9]{2})-(?<trace_id>[A-Fa-f0-9]{32})-(?<span_id>[A-Fa-f0-9]{32})-(?<flags>[A-Fa-f0-9]{2})(?<ignored>-.*)?$/
        end
      end
    end
  end
end

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
            instana_context = {}
            OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator.inject(instana_context)
            context = ::Instana.tracer.context
            job.arguments.append(instana_context: instana_context)

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
          incoming_context = if job.arguments.is_a?(Array) && job.arguments.last.is_a?(Hash) && job.arguments.last.key?(:instana_context)
                               instana_context = job.arguments.last[:instana_context]
                               job.arguments.pop
                               instana_context ? ::Instana::SpanContext.new(trace_id: instana_context[:trace_id], span_id: instana_context[:span_id]) : nil
                             end
          OpenTelemetry::Context.with_current(instana_context ? OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator.extract(instana_context) : OpenTelemetry::Context.current) do
            ::Instana.tracer.in_span(:activejob, attributes: tags) do
              block.call
            end
          end
        end
      end
    end
  end
end
