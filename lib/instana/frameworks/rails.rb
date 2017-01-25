require "instana/rack"

if defined?(::Rails)
  # In Rails, let's use the Rails logger
  ::Instana.logger = ::Rails.logger if ::Rails.logger

  if ::Rails::VERSION::MAJOR < 3
    ::Rails.configuration.after_initialization do
      ::Instana.logger.warn "Instrumenting Rack"
      ::Rails.configuration.middleware.insert 0, ::Instana::Rack
    end
  else
    module ::Instana
      class Railtie < ::Rails::Railtie
        initializer 'instana.rack' do |app|
          ::Instana.logger.warn "Instrumenting Rack"
          app.config.middleware.insert 0, ::Instana::Rack
        end

        config.after_initialize do
          require "instana/frameworks/instrumentation/active_record"
          require "instana/frameworks/instrumentation/action_controller"
          require "instana/frameworks/instrumentation/action_view"
        end
      end
    end
  end
end
