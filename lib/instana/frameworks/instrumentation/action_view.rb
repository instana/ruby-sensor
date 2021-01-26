module Instana
  module Instrumentation
    module ActionViewRenderer
      def render_partial(*args)
        kv_payload = { :render => {} }
        kv_payload[:render][:type] = :partial
        kv_payload[:render][:name] = @options[:partial].to_s if @options.is_a?(Hash)

        ::Instana.tracer.log_entry(:render, kv_payload)
        super(*args)
      rescue Exception => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:render)
      end

      def render_collection(*args)
        puts 'called'
        kv_payload = { :render => {} }
        kv_payload[:render][:type] = :collection
        kv_payload[:render][:name] = @path.to_s

        ::Instana.tracer.log_entry(:render, kv_payload)
        super(*args)
      rescue Exception => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:render)
      end
    end
  end
end

if defined?(::ActionView) && ::Instana.config[:action_view][:enabled] && ::ActionPack::VERSION::STRING >= '3.1'
  ::Instana.logger.debug "Instrumenting ActionView"
  ::ActionView::PartialRenderer.send(:prepend, ::Instana::Instrumentation::ActionViewRenderer)
end
