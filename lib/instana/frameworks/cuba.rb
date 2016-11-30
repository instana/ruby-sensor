require "instana/rack"

if defined?(::Cuba)
  ::Instana.logger.warn "Instana: Instrumenting Cuba"
  Cuba.use ::Instana::Rack
end
