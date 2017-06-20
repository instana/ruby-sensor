require "instana/rack"

if defined?(::Roda)
  ::Instana.logger.info "Instrumenting Roda"
  Roda.use ::Instana::Rack
end
