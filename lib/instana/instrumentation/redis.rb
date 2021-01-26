module Instana
  module RedisInstrumentation
    def call(*args, &block)
      kv_payload = { redis: {} }
      dnt_spans = [:redis, :'resque-client', :'sidekiq-client']

      if !Instana.tracer.tracing? || dnt_spans.include?(::Instana.tracer.current_span.name) || !Instana.config[:redis][:enabled]
        return super(*args, &block)
      end

      begin
        ::Instana.tracer.log_entry(:redis)

        begin
          kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
          kv_payload[:redis][:db] = db.to_s
          kv_payload[:redis][:command] = args[0][0].to_s.upcase
        rescue
          nil
        end

        super(*args, &block)
      rescue => e
        ::Instana.tracer.log_info({ redis: {error: true} })
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:redis, kv_payload)
      end
    end

    def call_pipeline(*args, &block)
      kv_payload = { redis: {} }
      dnt_spans = [:redis, :'resque-client', :'sidekiq-client']

      if !Instana.tracer.tracing? || dnt_spans.include?(::Instana.tracer.current_span.name) || !Instana.config[:redis][:enabled]
        return super(*args, &block)
      end

      begin
        ::Instana.tracer.log_entry(:redis)

        pipeline = args.first
        begin
          kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
          kv_payload[:redis][:db] = db.to_s
          kv_payload[:redis][:command] = pipeline.is_a?(::Redis::Pipeline::Multi) ? 'MULTI' : 'PIPELINE'
        rescue
          nil
        end

        super(*args, &block)
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

if defined?(::Redis) && ::Instana.config[:redis][:enabled]
  ::Instana.logger.debug "Instrumenting Redis"
  Redis::Client.prepend(::Instana::RedisInstrumentation)
end
