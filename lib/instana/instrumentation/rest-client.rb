# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

module Instana
  module Instrumentation
    module RestClientRequest
      def execute(&block)
        # Since RestClient uses net/http under the covers, we just
        # provide span visibility here.  HTTP related KVs are reported
        # in the Net::HTTP instrumentation
        span = ::Instana.tracer.start_span(:'rest-client', with_parent: OpenTelemetry::Context.current)

        Trace.with_span(span) do super(&block) end;
      rescue => e
        span.record_exception(e)
        raise
      ensure
        span.finish
      end
    end
  end
end
