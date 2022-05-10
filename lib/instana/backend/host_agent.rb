# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # @since 1.197.0
    class HostAgent
      attr_reader :future, :client

      def initialize(discovery: Concurrent::Atom.new(nil), logger: ::Instana.logger)
        @discovery = discovery
        @logger = logger
        @future = nil
        @client = nil
      end

      def setup; end

      def spawn_background_thread
        return if ENV.key?('INSTANA_TEST')

        @future = Concurrent::Promises.future do
          announce
        end
      end

      alias start spawn_background_thread

      def announce
        @client = until_not_nil { HostAgentLookup.new.call }
        @discovery.delete_observers
        @discovery
          .with_observer(HostAgentActivationObserver.new(@client, @discovery))
          .with_observer(HostAgentReportingObserver.new(@client, @discovery))

        @discovery.swap { nil }
        @client
      end

      alias after_fork announce

      # @return [Boolean] true if the agent able to send spans to the backend
      def ready?
        ENV.key?('INSTANA_TEST') || !@discovery.value.nil?
      end

      # @return [Hash, NilClass] the backend friendly description of the current in process collector
      def source
        {
          e: discovery_value['pid'],
          h: discovery_value['agentUuid']
        }.reject { |_, v| v.nil? }
      end

      # @return [Array] extra headers to capture with HTTP spans
      def extra_headers
        if discovery_value['tracing']
          # Starting with discovery version 1.6.4, this value is in tracing.extra-http-headers.
          discovery_value['tracing']['extra-http-headers']
        else
          # Legacy fallback for discovery versions <= 1.6.3.
          discovery_value['extraHeaders']
        end
      end

      # @return [Hash] values which are removed from urls sent to the backend
      def secret_values
        discovery_value['secrets']
      end

      private

      def until_not_nil
        loop do
          result = yield
          return result unless result.nil?

          @logger.debug("Waiting on a connection to the agent.")
          sleep(1)
        end
      end

      def discovery_value
        v = @discovery.value
        v || {}
      end
    end
  end
end
