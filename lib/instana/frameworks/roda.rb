require "instana/rack"

if defined?(::Roda)
  ::Instana.logger.warn "Instana: Instrumenting Roda"
  Roda.use ::Instana::Rack
end
