module Instana
  module Instrumentation
    module ActionViewRenderer
      def self.included(klass)
        ::Instana::Util.method_alias(klass, :render_partial)
        ::Instana::Util.method_alias(klass, :render_collection)
      end

      def render_partial_with_instana
        kv_payload = { :render => {} }
        kv_payload[:render][:type] = :partial
        kv_payload[:render][:name] = @options[:partial].to_s if @options.is_a?(Hash)

        ::Instana.tracer.log_entry(:render, kv_payload)
        render_partial_without_instana
      rescue Exception => e
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:render)
      end

      def render_collection_with_instana
        kv_payload = { :render => {} }
        kv_payload[:render][:type] = :collection
        kv_payload[:render][:name] = @path.to_s

        ::Instana.tracer.log_entry(:render, kv_payload)
        render_collection_without_instana
      rescue Exception => e
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:render)
      end
    end
  end
end

if defined?(::ActionView) && ::Instana.config[:action_view][:enabled] && ::ActionPack::VERSION::STRING >= '3.1'
  ::Instana.logger.warn "Instrumenting ActionView"
  ::ActionView::PartialRenderer.send(:include, ::Instana::Instrumentation::ActionViewRenderer)
end
