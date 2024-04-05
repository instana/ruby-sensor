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
            # Rails 7.0.3 `tagged_logging.rb` has a number of bugs.
            # What pertains to our instrumentation here is that in
            # https://github.com/rails/rails/blob/v7.0.3/activesupport/lib/active_support/tagged_logging.rb#L100
            # sets the `other_logger.formatter` to `formatter` if `other_logger.formatter` is `nil`
            # but then
            # https://github.com/rails/rails/blob/v7.0.3/activesupport/lib/active_support/tagged_logging.rb#L102
            # redefines `formatter.current_tags` method to a proc calling `formatter.current_tags`, itself.
            # which is an infinite recursion.
            #
            # This bug starts with 7.0.3:
            # https://github.com/rails/rails/compare/v7.0.2...v7.0.3#diff-68f90ba4998610be2f7da027e006e8ddeeb06dece66f41579c94070e12f23011
            # And is already reverted/fixed in 7.0.4
            # https://github.com/rails/rails/compare/v7.0.3...v7.0.4#diff-68f90ba4998610be2f7da027e006e8ddeeb06dece66f41579c94070e12f23011
            # The commit which fixes it is:
            # https://github.com/rails/rails/commit/ff277583e22ddfbcfbd2131789a7cb7c2f868d68
            #
            # Since instana does trigger this bug here we workaround it, by defining the `formatter`,
            # to break the infinite loop. The `formatter` used here is the same as the default used in
            # https://github.com/rails/rails/blob/v7.0.3/activesupport/lib/active_support/tagged_logging.rb#L89C9-L89C70
            if ::Rails::VERSION::STRING == "7.0.3"
              logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
            end
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
