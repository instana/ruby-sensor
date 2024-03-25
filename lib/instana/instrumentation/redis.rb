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

      def call_v(*args, &block)
        if skip_instrumentation?
          super(*args, &block)
        else
          call_with_instana(args[0][0].to_s.upcase, ORIGINAL_METHODS[:call_v], *args, &block)
        end
      end

      def pipelined(*args, &block)
        if skip_instrumentation?
          super(*args, &block)
        else
          call_with_instana('PIPELINE', ORIGINAL_METHODS[:pipelined], *args, &block)
        end
      end

      # Since, starting with 5.1 redis/client.rb:114:multi takes an unused default argument `watch: nil`
      # but calls redis_client.rb:442:multi, which doesn't take any argument,
      # here we have to take arguments but we should not use it.
      def multi(*_, &block)
        if skip_instrumentation?
          super(&block)
        else
          call_with_instana('MULTI', ORIGINAL_METHODS[:multi], &block)
        end
      end

    else
      ORIGINAL_METHODS = {
        :call => ::Redis::Client.instance_method(:call),
        :call_pipeline => ::Redis::Client.instance_method(:call_pipeline)
      }.freeze

      def call(*args, &block)
        if skip_instrumentation?
          super(*args, &block)
        else
          call_with_instana(args[0][0].to_s.upcase, ORIGINAL_METHODS[:call], *args, &block)
        end
      end

      def call_pipeline(*args, &block)
        if skip_instrumentation?
          super(*args, &block)
        else
          call_with_instana(args.first.is_a?(::Redis::Pipeline::Multi) ? 'MULTI' : 'PIPELINE', ORIGINAL_METHODS[:call_pipeline], *args, &block)
        end
      end
    end

    def skip_instrumentation?
      dnt_spans = [:redis, :'resque-client', :'sidekiq-client']
      !Instana.tracer.tracing? || dnt_spans.include?(::Instana.tracer.current_span.name) || !Instana.config[:redis][:enabled]
    end

    def call_with_instana(*args, &block)
      command, original_super, *original_args = *args
      kv_payload = { redis: {} }

      begin
        ::Instana.tracer.log_entry(:redis)

        begin
          kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
          kv_payload[:redis][:db] = db.to_s
          kv_payload[:redis][:command] = command
        rescue
          nil
        end
        original_super.bind(self).call(*original_args, &block)
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
