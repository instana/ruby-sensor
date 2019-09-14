require "instana/rack"

if defined?(::Cuba)
  ::Instana.logger.debug "Instrumenting Cuba"
  Cuba.use ::Instana::Rack
end
