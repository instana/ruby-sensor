if defined?(::Redis) && ::Instana.config[:redis][:enabled]
  ::Redis::Client.class_eval do
    def call_with_instana(*args, &block)
      kv_payload = { redis: {} }

      if !Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:redis)
        return call_without_instana(*args, &block)
      end

      ::Instana.tracer.log_entry(:redis)

      begin
        kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
        kv_payload[:redis][:db] = db.to_s
        kv_payload[:redis][:command] = args[0][0].to_s.upcase
      rescue
        nil
      end

      call_without_instana(*args, &block)
    rescue => e
      ::Instana.tracer.log_info({ redis: {error: true} })
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_exit(:redis, kv_payload)
    end

    ::Instana.logger.debug "Instrumenting Redis"

    alias call_without_instana call
    alias call call_with_instana

    def call_pipeline_with_instana(*args, &block)
      kv_payload = { redis: {} }

      if !Instana.tracer.tracing? || ::Instana.tracer.tracing_span?(:redis)
        return call_pipeline_without_instana(*args, &block)
      end

      ::Instana.tracer.log_entry(:redis)

      pipeline = args.first
      begin
        kv_payload[:redis][:connection] = "#{self.host}:#{self.port}"
        kv_payload[:redis][:db] = db.to_s
        kv_payload[:redis][:command] = pipeline.is_a?(::Redis::Pipeline::Multi) ? 'MULTI' : 'PIPELINE'
      rescue
        nil
      end

      call_pipeline_without_instana(*args, &block)
    rescue => e
      ::Instana.tracer.log_info({ redis: {error: true} })
      ::Instana.tracer.log_error(e)
      raise
    ensure
      ::Instana.tracer.log_exit(:redis, kv_payload)
    end

    alias call_pipeline_without_instana call_pipeline
    alias call_pipeline call_pipeline_with_instana
  end
end
