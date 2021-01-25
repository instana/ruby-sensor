module Instana
  module Instrumentation
    module RestClientRequest
      def execute(&block)
        # Since RestClient uses net/http under the covers, we just
        # provide span visibility here.  HTTP related KVs are reported
        # in the Net::HTTP instrumentation
        ::Instana.tracer.log_entry(:'rest-client')

        super(&block)
      rescue => e
        ::Instana.tracer.log_error(e)
        raise
      ensure
        ::Instana.tracer.log_exit(:'rest-client')
      end
    end
  end
end

if defined?(::RestClient::Request) && ::Instana.config[:'rest-client'][:enabled]
  ::Instana.logger.debug "Instrumenting RestClient"
  ::RestClient::Request.send(:prepend, ::Instana::Instrumentation::RestClientRequest)
end
