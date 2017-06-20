require "instana/rack"

# This instrumentation will insert Rack into Sinatra _and_ Padrino since
# the latter is based on Sinatra

if defined?(::Sinatra)
  ::Instana.logger.info "Instrumenting Sinatra"
  ::Sinatra::Base.use ::Instana::Rack
end
