require "instana/rack"

if defined?(::Roda)
  ::Instana.logger.debug "Instrumenting Roda"
  Roda.use ::Instana::Rack
end
