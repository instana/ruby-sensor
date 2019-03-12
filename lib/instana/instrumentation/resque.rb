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
          kvs[:queue] = klass.instance_variable_get(:@queue)
        rescue => e
          Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        end

        { :'resque-client' => kvs }
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
        kvs[:'resque-worker'] = {}

        begin
          if ENV.key?('INSTANA_SERVICE_NAME')
            kvs[:service] = ENV['INSTANA_SERVICE_NAME']
          end
          kvs[:'resque-worker'][:job] = job.payload['class'].to_s
          kvs[:'resque-worker'][:queue] = job.queue
        rescue => e
          ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if Instana::Config[:verbose]
        end

        Instana.tracer.start_or_continue_trace(:'resque-worker', kvs) do
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
          ::Instana.tracer.log_info(:'resque-worker' => { :error => "#{exception.class}: #{exception}"})
          ::Instana.tracer.log_error(exception)
        end
      rescue Exception => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if Instana::Config[:verbose]
      ensure
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

    ::Resque.before_fork do |job|
      ::Instana.agent.before_resque_fork
    end
    ::Resque.after_fork do |job|
      ::Instana.agent.after_resque_fork
    end

    # Set this so we assure that any remaining collected traces are reported at_exit
    ENV['RUN_AT_EXIT_HOOKS'] = "1"
  end
end
