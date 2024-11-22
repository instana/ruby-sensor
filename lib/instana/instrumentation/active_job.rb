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

          ::Instana::Tracer.trace(:activejob, tags) do
            context = ::Instana.tracer.context
            if job.arguments.is_a?(Array) && job.arguments.last.is_a?(Hash)
              job.arguments.last[:instana_context] = context ? context.to_hash : nil
            end

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

          incoming_context = if job.arguments.is_a?(Array) && job.arguments.last.is_a?(Hash)
                               instana_context = job.arguments.last[:instana_context]
                               job.arguments.last.delete(:instana_context)
                               instana_context ? ::Instana::SpanContext.new(instana_context[:trace_id], instana_context[:span_id]) : nil
                             end

          ::Instana::Tracer.start_or_continue_trace(:activejob, tags, incoming_context) do
            block.call
          end
        end
      end
    end
  end
end
