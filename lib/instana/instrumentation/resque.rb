# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

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

          if defined?(::Resque) && ::Resque.respond_to?(:redis) && ::Resque.redis
            client = ::Resque.redis
            client = client.redis if client.respond_to?(:redis)

            host, port = if client.respond_to?(:config) && client.config.respond_to?(:host) && client.config.respond_to?(:port)
                           [client.config.host, client.config.port]
                         elsif client.respond_to?(:connection)
                           [client.connection[:host], client.connection[:port]]
                         elsif client.respond_to?(:client) && client.client.respond_to?(:options)
                           [client.client.options[:host], client.client.options[:port]]
                         end

            kvs[:'redis-url'] = "#{host}:#{port}" if host && port
          end
        rescue => e
          Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        end

        { :'resque-client' => kvs }
      end

      def enqueue(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:enqueue, klass, args)

          Instana.tracer.in_span(:'resque-client', attributes: kvs) do
            args.push(::Instana.tracer.context.to_hash) if ::Instana.config[:'resque-client'][:propagate]
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

          Instana.tracer.in_span(:'resque-client', attributes: kvs) do
            args.push(::Instana.tracer.context.to_hash) if ::Instana.config[:'resque-client'][:propagate]
            super(queue, klass, *args)
          end
        else
          super(queue, klass, *args)
        end
      end

      def dequeue(klass, *args)
        if Instana.tracer.tracing?
          kvs = collect_kvs(:dequeue, klass, args)

          Instana.tracer.in_span(:'resque-client', attributes: kvs) do
            super(klass, *args)
          end
        else
          super(klass, *args)
        end
      end
    end

    module ResqueWorker
      def perform(job) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        kvs = {}
        kvs[:'resque-worker'] = {}

        begin
          kvs[:'resque-worker'][:job] = job.payload['class'].to_s
          kvs[:'resque-worker'][:queue] = job.queue

          if defined?(::Resque) && ::Resque.respond_to?(:redis) && ::Resque.redis
            client = ::Resque.redis
            client = client.redis if client.respond_to?(:redis)

            host, port = if client.respond_to?(:config) && client.config.respond_to?(:host) && client.config.respond_to?(:port)
                           [client.config.host, client.config.port]
                         elsif client.respond_to?(:connection)
                           [client.connection[:host], client.connection[:port]]
                         elsif client.respond_to?(:client) && client.client.respond_to?(:options)
                           [client.client.options[:host], client.client.options[:port]]
                         end

            kvs[:'resque-worker'][:'redis-url'] = "#{host}:#{port}" if host && port
          end
        rescue => e
          ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" } if Instana::Config[:verbose]
        end

        trace_context = if ::Instana.config[:'resque-client'][:propagate] && job.payload['args'][-1].is_a?(Hash) && job.payload['args'][-1].keys.include?('trace_id')
                          context_from_wire = job.payload['args'].pop
                          ::Instana::SpanContext.new(
                            trace_id: context_from_wire['trace_id'],
                            span_id: context_from_wire['span_id'],
                            level: context_from_wire['level'] || 1
                          )
                        end
        span = OpenTelemetry::Trace.non_recording_span(trace_context) if trace_context
        Trace.with_span(span) do
          Instana.tracer.in_span(:'resque-worker', attributes: kvs) do |span|
            super(job)
          end
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
