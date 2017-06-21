require "instana/rack"

if defined?(::Cuba)
  ::Instana.logger.info "Instrumenting Cuba"
  Cuba.use ::Instana::Rack
end
