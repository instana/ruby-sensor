require "instana/rack"

if defined?(::Cuba)
  ::Instana.logger.warn "Instrumenting Cuba"
  Cuba.use ::Instana::Rack
end
