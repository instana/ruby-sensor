require 'socket'

module Instana
  module Instrumentation
    module ResqueClient
      def self.included(klass)
        klass.send :extend, ::Resque
        ::Instana::Util.method_alias(klass, :enqueue)
        ::Instana::Util.method_alias(klass, :enqueue_to)
        ::Instana::Util.method_alias(klass, :dequeue)
      end

      def collect_kvs(op, klass, args)
        kvs = {}

        begin
          kvs[:job] = klass.to_s
          kvs[:args] = args.to_json
          kvs[:queue] = klass.instance_variable_get(:@queue)
        rescue => e
          Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        kvs
      end

      def enqueue_with_instana(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:enqueue, klass, args)

          Instana.tracer.trace(:'resque-client', kvs) do
            enqueue_without_instana(klass, *args)
          end
        else
          enqueue_without_instana(klass, *args)
        end
      end

      def enqueue_to_with_instana(queue, klass, *args)
        if Instana.tracer.tracing? && !Instana.tracer.tracing_span?(:'resque-client')
          kvs = collect_kvs(:enqueue_to, klass, args)
          kvs[:Queue] = queue.to_s if queue

          Instana.tracer.trace(:'resque-client', kvs) do
            enqueue_to_without_instana(queue, klass, *args)
          end
        else
          enqueue_to_without_instana(queue, klass, *args)
        end
      end

      def dequeue_with_instana(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:dequeue, klass, args)

          Instana.tracer.trace(:'resque-client', kvs) do
            dequeue_without_instana(klass, *args)
          end
        else
          dequeue_without_instana(klass, *args)
        end
      end
    end

    module ResqueWorker
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :perform)
      end

      def perform_with_instana(job)
        kvs = {}

        begin
          kvs[:job] = job.payload['class'].to_s
          kvs[:queue] = job.queue
          kvs[:args] = job.payload['args'].to_json
        rescue => e
          Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if Instana::Config[:verbose]
        end

        Instana::tracer.start_or_continue_trace(:'resque-worker', nil, kvs) do
          perform_without_instana(job)
        end
      end
    end

    module ResqueJob
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :fail)
      end

      def fail_with_instana(exception)
        if Instana.tracer.tracing?
          Instana::tracer.log_error(:resque, exception)
        end
        fail_without_instana(exception)
      end
    end
  end
end

if defined?(::Resque) && RUBY_VERSION >= '1.9.3'

  if ::Instana.config[:'resque-client'][:enabled]
    ::Instana.logger.info 'Instrumenting Resque Client'
    ::Instana::Util.send_include(::Resque,         ::Instana::Instrumentation::ResqueClient)
  end

  if ::Instana.config[:'resque-worker'][:enabled]
    ::Instana.logger.info 'Instrumenting Resque Worker'

    ::Instana::Util.send_include(::Resque::Worker, ::Instana::Instrumentation::ResqueWorker)
    ::Instana::Util.send_include(::Resque::Job,    ::Instana::Instrumentation::ResqueJob)

    ::Resque.after_fork do |job|
      ::Instana.logger.debug("After fork hook for Resque Job")
      ::Instana.agent.after_fork
    end
  end
end
