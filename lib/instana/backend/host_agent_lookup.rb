# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'csv'

module Instana
  module Backend
    # Utility class to discover the agent that a given instance of the collector
    # needs to communicate with.
    # @since 1.195.4
    class HostAgentLookup
      def initialize(host = ::Instana.config[:agent_host], port = ::Instana.config[:agent_port], destination: '00000000')
        @host = host
        @port = port
        @destination = destination
      end

      # @return [RequestClient, NilClass] the request client to use to communicate with the agent or nil if no agent could be found
      def call
        host_listening?(@host, @port) || host_listening?(default_gateway, @port)
      end

      private

      # @return [RequestClient, nil] the request client if it responds to '/' with a success
      def host_listening?(host, port)
        client = RequestClient.new(host, port)
        client.send_request('GET', '/').ok? ? client : nil
      rescue Net::OpenTimeout => _e
        nil
      end

      # @return [String] the default gateway to attempt to connect to or the @host if a default gateway can not be identified
      def default_gateway
        return @host unless File.exist?('/proc/self/net/route')

        routes = CSV.read(
          '/proc/self/net/route',
          headers: :first_row,
          col_sep: "\t",
          header_converters: [->(v) { v.strip }],
          converters: [->(v) { v.strip }]
        )

        route = routes.detect { |r| r['Destination'] == @destination }
        return @host unless route

        route['Gateway']
          .split(/([0-9A-Z]{2})/)
          .reject(&:empty?)
          .reverse
          .map { |s| s.to_i(16) }
          .join('.')
      end
    end
  end
end
