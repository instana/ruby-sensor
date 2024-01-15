# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

if ::Rails::VERSION::MAJOR < 3
  ::Rails.configuration.after_initialize do
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
        # Configure the Instrumented Logger
        if ::Instana.config[:logging][:enabled] && !ENV.key?('INSTANA_TEST')
          logger = ::Instana::InstrumentedLogger.new('/dev/null')
          if ::Rails::VERSION::STRING < "7.1"
            Rails.logger.extend(ActiveSupport::Logger.broadcast(logger))
          else
            Rails.logger.broadcast_to(logger)
          end
        end

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
