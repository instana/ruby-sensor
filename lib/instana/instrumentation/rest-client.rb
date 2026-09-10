# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'instana/util'

module Instana
  module Instrumentation
    module RestClientRequest
      def execute(&block)
        # Since RestClient uses net/http under the covers, we just
        # provide span visibility here.  HTTP related KVs are reported
        # in the Net::HTTP instrumentation
        span = ::Instana.tracer.start_span(:'rest-client', with_parent: OpenTelemetry::Context.current)

        Trace.with_span(span) { super(&block) }
      rescue => e
        span.record_exception(e) if error_span?(e)
        raise
      ensure
        span.finish
      end

      private

      def error_span?(exception)
        if exception.respond_to?(:response) && exception.response.respond_to?(:code)
          ::Instana::Util.should_mark_http_exit_as_error?(exception.response.code.to_i)
        else
          true
        end
      end
    end
  end
end
