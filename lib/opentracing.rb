require "instana/opentracing/tracer"
require "instana/opentracing/carrier"

# Set the global tracer to our OT tracer
# which supports the OT specification
OpenTracing.global_tracer = ::Instana.tracer
