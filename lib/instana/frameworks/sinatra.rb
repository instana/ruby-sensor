require "instana/rack"

# This instrumentation will insert Rack into Sinatra _and_ Padrino since
# the latter is based on Sinatra

module Instana
  module SinatraPathTemplateExtractor
    def self.extended(base)
      ::Instana.logger.debug "#{base} extended #{self}"
      base.store_path_template
    end
    
    def store_path_template
      after do
        @env["INSTANA_HTTP_PATH_TEMPLATE"] = @env["sinatra.route"]
          .sub("#{@request.request_method} ", '')
      end
    end
  end
end

if defined?(::Sinatra)
  ::Instana.logger.debug "Instrumenting Sinatra"
  ::Sinatra::Base.use ::Instana::Rack
  ::Sinatra::Base.register ::Instana::SinatraPathTemplateExtractor
end
