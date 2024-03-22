# (c) Copyright IBM Corp. 2024
# (c) Copyright Instana Inc. 2017

module Instana
  module RedisInstrumentation
    ORIGINAL_METHODS = {
      :call => ::Redis::Client.instance_method(:call),
      :call_pipeline => ::Redis::Client.instance_method(:call_pipeline)
    }.freeze

    def skip_instrumentation?
      dnt_spans = [:redis, :'resque-client', :'sidekiq-client']
      !Instana.tracer.tracing? || dnt_spans.include?(::Instana.tracer.current_span.name) || !Instana.config[:redis][:enabled]
    end

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
