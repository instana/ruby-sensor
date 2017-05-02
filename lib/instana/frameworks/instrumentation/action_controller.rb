module Instana
  module Instrumentation

    # Contains the methods common to both ::Instana::Instrumentation::ActionController
    # and ::Instana::Instrumentation::ActionControllerLegacy
    #
    module ActionControllerCommon

      # Indicates whether a Controller rescue handler is in place.  If so, this affects
      # error logging and reporting. (Hence the need for this method).
      #
      # @return [Boolean]
      #
      def has_rails_handler?
        found = false
        rescue_handlers.detect do |klass_name, _handler|
          # Rescue handlers can be specified as strings or constant names
          klass = self.class.const_get(klass_name) rescue nil
          klass ||= klass_name.constantize rescue nil
          found = exception.is_a?(klass) if klass
        end
        found
      rescue => e
        ::Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        return false
      end

      # Render can be called with many options across the various supported
      # versions of Rails.  This method attempts to make sense and provide
      # insight into what is happening (rendering a layout, file, nothing,
      # plaintext etc.)
      def get_render_topic(opts)
        if opts.key?(:layout)
          case opts[:layout]
          when FalseClass
            name = "Without layout"
          when String
            name = opts[:layout]
          when Proc
            name = "Proc"
          else
            name = "Default"
          end
        end
        name ||= opts[:template]
        name ||= opts[:file]
        name = "Nothing" if opts[:nothing]
        name = "Plaintext" if opts[:plain]
        name
      end
    end

    # Used in ActionPack versions 5 and beyond, this module provides
    # instrumentation for ActionController (a part of ActionPack)
    #
    module ActionController
      include ::Instana::Instrumentation::ActionControllerCommon

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
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:actioncontroller)
      end

      # The Instana wrapper method for ActionController::Base.render
      # for versions 5+.
      #
      def render(*args, &blk)
        # Figure out what's being rendered
        if args.length > 0 && args[0].is_a?(Hash)
          name = get_render_topic(args[0])
        end
        name ||= "Default"

        ::Instana.tracer.log_entry(:actionview, :actionview => { :name => name })

        super(*args, &blk)
      rescue Exception => e
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:actionview)
      end
    end

    # Used in ActionPack versions 4 and earlier, this module provides
    # instrumentation for ActionController (a part of ActionPack)
    #
    module ActionControllerLegacy
      include ::Instana::Instrumentation::ActionControllerCommon

      def self.included(klass)
        klass.class_eval do
          alias_method_chain :process_action, :instana
          alias_method_chain :render, :instana
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
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:actioncontroller)
      end

      # The Instana wrapper method for ActionController::Base.render
      # for versions 3 and 4.
      #
      def render_with_instana(*args, &blk)
        if args.length > 0 && args[0].is_a?(Hash)
          name = get_render_topic(args[0])
        end
        name ||= "Default"
        ::Instana.tracer.log_entry(:actionview, :actionview => { :name => name })
        render_without_instana(*args, &blk)
      rescue Exception => e
        ::Instana.tracer.log_error(e) unless has_rails_handler?
        raise
      ensure
        ::Instana.tracer.log_exit(:actionview)
      end
    end
  end
end

if defined?(::ActionController) && ::Instana.config[:action_controller][:enabled] && ::ActionPack::VERSION::MAJOR >= 2
  ::Instana.logger.warn "Instrumenting ActionController"
  if ActionPack::VERSION::MAJOR >= 5
    ::ActionController::Base.send(:prepend, ::Instana::Instrumentation::ActionController)
  else
    ::ActionController::Base.send(:include, ::Instana::Instrumentation::ActionControllerLegacy)
  end
end

# ActionController::API was introduced in Ruby on Rails 5 but was originally an independent project before being
# rolled into the Rails ActionPack.  In case, someone is using the independent project or potentially backported
# the rails version to and older Ruby on Rails version, we only limit in a minimal way re: version checking.
#
# We allow ActionController::API instrumentation in version of Ruby on Rails 3 and higher.
#
if defined?(::ActionController::API) && ::Instana.config[:action_controller][:enabled] && ::ActionPack::VERSION::MAJOR >= 3
  ::Instana.logger.warn "Instrumenting ActionController API"
  ::ActionController::API.send(:prepend, ::Instana::Instrumentation::ActionController)
end
