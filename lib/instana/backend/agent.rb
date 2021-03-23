# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # @since 1.195.4
    class Agent
      def initialize(discovery: Concurrent::Atom.new(nil))
        @discovery = discovery
        @client = nil
      end

      def setup
        return if ENV.key?('INSTANA_TEST')

        @client = HostAgentLookup.new.call
        @discovery
          .with_observer(HostAgentActivationObserver.new(@client, @discovery))
          .with_observer(HostAgentReportingObserver.new(@client, @discovery))
      end

      def spawn_background_thread
        @discovery.swap { nil }
      end

      # @return [Boolean] true if the agent able to send spans to the backend
      def ready?
        ENV.key?('INSTANA_TEST') || !@discovery.value.nil?
      end

      # @return [Hash, NilClass] the backend friendly description of the current in process collector
      def source
        {
          e: discovery_value['pid'],
          h: discovery_value['agentUuid']
        }.compact
      end

      # @return [Array] extra headers to include in the trace
      def extra_headers
        discovery_value['extraHeaders']
      end

      # @return [Hash] values which are removed from urls sent to the backend
      def secret_values
        discovery_value['secrets']
      end

      private

      def discovery_value
        v = @discovery.value
        v || {}
      end
    end
  end
end
