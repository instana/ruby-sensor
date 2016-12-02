require "instana/rack"

if defined?(::Roda)
  ::Instana.logger.warn "Instrumenting Roda"
  Roda.use ::Instana::Rack
end
