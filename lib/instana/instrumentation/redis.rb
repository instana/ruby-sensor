# (c) Copyright IBM Corp. 2024
# (c) Copyright Instana Inc. 2017

module Instana
  module RedisInstrumentation
    if Gem::Specification.find_by_name('redis').version >= Gem::Version.new('5.0') && defined?(::RedisClient)
      ORIGINAL_METHODS = {
        :call_v => ::RedisClient.instance_method(:call_v),
        :pipelined => ::RedisClient.instance_method(:pipelined),
        :multi => ::RedisClient.instance_method(:multi)
      }.freeze

      def call_v(*args, **kwargs, &block)
        if skip_instrumentation?
          super(*args, **kwargs, &block)
        else
          call_with_instana(args[0][0].to_s.upcase, ORIGINAL_METHODS[:call_v], args, kwargs, &block)
        end
      end

      def pipelined(*args, **kwargs, &block)
        if skip_instrumentation?
          super(*args, **kwargs, &block)
        else
          call_with_instana('PIPELINE', ORIGINAL_METHODS[:pipelined], args, kwargs, &block)
        end
      end

      def multi(*args, **kwargs, &block)
        if skip_instrumentation?
          super(*args, **kwargs, &block)
        else
          call_with_instana('MULTI', ORIGINAL_METHODS[:multi], args, kwargs, &block)
        end
      end

    else
      ORIGINAL_METHODS = {
        :call => ::Redis::Client.instance_method(:call),
        :call_pipeline => ::Redis::Client.instance_method(:call_pipeline)
      }.freeze

      def call(*args, **kwargs, &block)
        if skip_instrumentation?
          super(*args, **kwargs, &block)
        else
          call_with_instana(args[0][0].to_s.upcase, ORIGINAL_METHODS[:call], args, kwargs, &block)
        end
      end

      def call_pipeline(*args, **kwargs, &block)
        if skip_instrumentation?
          super(*args, **kwargs, &block)
        else
          call_with_instana(args.first.is_a?(::Redis::Pipeline::Multi) ? 'MULTI' : 'PIPELINE', ORIGINAL_METHODS[:call_pipeline], args, kwargs, &block)
        end
      end
    end

    def skip_instrumentation?
      dnt_spans = [:redis, :'resque-client', :'sidekiq-client']
      !Instana.tracer.tracing? || (!::Instana.tracer.current_span.nil? && dnt_spans.include?(::Instana.tracer.current_span.name)) || !Instana.config[:redis][:enabled]
    end

    def call_with_instana(command, original_super, args, kwargs, &block)
      kv_payload = { redis: {} }

      begin
        ::Instana.tracer.start_span(:redis)

        begin
          kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
          kv_payload[:redis][:db] = db.to_s
          kv_payload[:redis][:command] = command
        rescue
          nil
        end
        original_super.bind(self).call(*args, **kwargs, &block)
      rescue => e
        ::Instana.tracer.log_info({ redis: {error: true} })
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:redis, kv_payload)
      end
    end
  end
end
