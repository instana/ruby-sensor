module Instana
  module Instrumentation
    module ActionController
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :process_action, :instana
        end
      end

      def process_action_with_instana(*args)
        kv_payload = { :actioncontroller => {} }
        kv_payload[:actioncontroller][:controller] = self.class.name
        kv_payload[:actioncontroller][:action] = action_name

        ::Instana.tracer.log_entry(:actioncontroller, kv_payload)
        process_action_without_instana(*args)
      rescue => e
        ::Instana.tracer.log_error(e)
      ensure
        ::Instana.tracer.log_exit(:actioncontroller)
      end
    end
  end
end
