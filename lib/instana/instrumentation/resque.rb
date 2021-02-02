require 'socket'

module Instana
  module Instrumentation
    module ResqueClient
      def self.prepended(klass)
        klass.send :extend, ::Resque
      end

      def collect_kvs(op, klass, args)
        kvs = {}

        begin
          kvs[:job] = klass.to_s
          kvs[:queue] = klass.instance_variable_get(:@queue)
        rescue => e
          Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        end

        { :'resque-client' => kvs }
      end

      def enqueue(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:enqueue, klass, args)

          Instana.tracer.trace(:'resque-client', kvs) do
            super(klass, *args)
          end
        else
          super(klass, *args)
        end
      end

      def enqueue_to(queue, klass, *args)
        if Instana.tracer.tracing? && !Instana.tracer.tracing_span?(:'resque-client')
          kvs = collect_kvs(:enqueue_to, klass, args)
          kvs[:Queue] = queue.to_s if queue

          Instana.tracer.trace(:'resque-client', kvs) do
            super(queue, klass, *args)
          end
        else
          super(queue, klass, *args)
        end
      end

      def dequeue(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:dequeue, klass, args)

          Instana.tracer.trace(:'resque-client', kvs) do
            super(klass, *args)
          end
        else
          super(klass, *args)
        end
      end
    end

    module ResqueWorker
      def perform(job)
        kvs = {}
        kvs[:'resque-worker'] = {}

        begin
          if ENV.key?('INSTANA_SERVICE_NAME')
            kvs[:service] = ENV['INSTANA_SERVICE_NAME']
          end
          kvs[:'resque-worker'][:job] = job.payload['class'].to_s
          kvs[:'resque-worker'][:queue] = job.queue
        rescue => e
          ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" } if Instana::Config[:verbose]
        end

        Instana.tracer.start_or_continue_trace(:'resque-worker', kvs) do
          super(job)
        end
      end
    end

    module ResqueJob
      def fail(exception)
        if Instana.tracer.tracing?
          ::Instana.tracer.log_info(:'resque-worker' => { :error => "#{exception.class}: #{exception}"})
          ::Instana.tracer.log_error(exception)
        end
      rescue Exception => e
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" } if Instana::Config[:verbose]
      ensure
        super(exception)
      end
    end
  end
end
