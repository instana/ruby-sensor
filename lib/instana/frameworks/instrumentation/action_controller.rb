module Instana
  module Instrumentation
    module ActionController
      # This is the Rails 5 version of the process_action method where we use prepend to
      # instrument the class method instead of using the older alias_method_chain.
      #
      def process_action(*args)
        kv_payload = { :actioncontroller => {} }
        kv_payload[:actioncontroller][:controller] = self.class.name
        kv_payload[:actioncontroller][:action] = action_name

        ::Instana.tracer.log_entry(:actioncontroller, kv_payload)

        super(*args)
      rescue Exception => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:actioncontroller)
      end
    end

    module ActionControllerLegacy
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :process_action, :instana
        end
      end

      # The Instana wrapper method for ActionController::Base.process_action
      # for versions 3 and 4.
      #
      def process_action_with_instana(*args)
        kv_payload = { :actioncontroller => {} }
        kv_payload[:actioncontroller][:controller] = self.class.name
        kv_payload[:actioncontroller][:action] = action_name

        ::Instana.tracer.log_entry(:actioncontroller, kv_payload)

        process_action_without_instana(*args)
      rescue Exception => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:actioncontroller)
      end
    end
  end
end

if defined?(::ActionController) && ::Instana.config[:action_controller][:enabled] && ::ActionPack::VERSION::MAJOR >= 3
  ::Instana.logger.warn "Instrumenting ActionController"
  if ActionPack::VERSION::MAJOR >= 5
    ::ActionController::Base.send(:prepend, ::Instana::Instrumentation::ActionController)
    ::Instana.logger.warn "Instrumenting ActionController API"
    ::ActionController::API.send(:prepend, ::Instana::Instrumentation::ActionController)
  else
    ::ActionController::Base.send(:include, ::Instana::Instrumentation::ActionControllerLegacy)
  end
end
