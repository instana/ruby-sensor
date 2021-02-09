# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

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
