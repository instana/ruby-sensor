if ::Rails::VERSION::MAJOR < 3
  ::Rails.configuration.after_initialize do
    # In Rails, let's use the Rails logger
    ::Instana.logger = ::Rails.logger if ::Rails.logger

    if ::Instana.config[:tracing][:enabled]
      ::Instana.logger.debug "Instrumenting Rack"
      ::Rails.configuration.middleware.insert 0, ::Instana::Rack
    else
      ::Instana.logger.info "Rack: Tracing disabled via config.  Not enabling middleware."
    end
  end
else
  module ::Instana
    class Railtie < ::Rails::Railtie
      initializer 'instana.rack' do |app|
        # In Rails, let's use the Rails logger
        ::Instana.logger = ::Rails.logger if ::Rails.logger

        if ::Instana.config[:tracing][:enabled]
          ::Instana.logger.debug "Instrumenting Rack"
          app.config.middleware.insert 0, ::Instana::Rack
        else
          ::Instana.logger.info "Rack: Tracing disabled via config.  Not enabling middleware."
        end
      end
    end
  end
end
