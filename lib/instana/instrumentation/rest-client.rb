module Instana
  module Instrumentation
    module RestClientRequest
      def self.included(klass)
        if klass.method_defined?(:execute)
          klass.class_eval do
            alias execute_without_instana execute
            alias execute execute_with_instana
          end
        end
      end

      def execute_with_instana & block
        # Since RestClient uses net/http under the covers, we just
        # provide span visibility here.  HTTP related KVs are reported
        # in the Net::HTTP instrumentation
        ::Instana.tracer.log_entry(:'rest-client')

        execute_without_instana(&block)
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
  ::RestClient::Request.send(:include, ::Instana::Instrumentation::RestClientRequest)
end
