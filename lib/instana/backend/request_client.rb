# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'net/http'
require 'delegate'
require 'json'

# :nocov:
begin
  require 'oj'
rescue LoadError => _e
  Instana.logger.warn("Unable to load Oj.")
end
# :nocov:

module Instana
  module Backend
    # Convince wrapper around {Net::HTTP}.
    # @since 1.197.0
    class RequestClient
      class Response < SimpleDelegator
        # @return [Hash] the decoded json response
        def json
          JSON.parse(body)
        end

        # @return [Boolean] true if the request was successful
        def ok?
          __getobj__.is_a?(Net::HTTPSuccess)
        end
      end

      def initialize(host, port, use_ssl: false)
        @client = Net::HTTP.start(host, port, use_ssl: use_ssl)
      end

      # Send a request to the backend. If data is a {Hash},
      # encode the object as JSON and set the proper headers.
      #
      # @param [String] method request method
      # @param [String] path request path
      # @param [Hash, String] data request body
      # @param [Hash] headers extra request headers to send
      def send_request(method, path, data = nil, headers = {})
        body = if data.is_a?(Hash) || data.is_a?(Array)
                 headers['Content-Type'] = 'application/json'
                 headers['Accept'] = 'application/json'

                 encode_body(data)
               else
                 headers['Content-Type'] = 'application/octet-stream'

                 data
               end

        response = @client.send_request(method, path, body, headers)
        Response.new(response)
      end

      # @return [Integer, NilClass] the fileno of the Net::HTTP socket or nil if it can't be identified
      def fileno
        socket = @client.instance_variable_get('@socket')
        io = socket && socket.instance_variable_get('@io')
        io && io.fileno
      end

      # @return [String] the inode asscoated with the Net::HTTP socket or nil if it can't be identified
      def inode
        path = "/proc/self/fd/#{fileno}"
        return unless File.exist?(path) && fileno

        File.readlink(path)
      end

      private

      def encode_body(data)
        # :nocov:
        defined?(Oj) ? Oj.dump(data, mode: :strict) : JSON.dump(data)
        # :nocov:
      end
    end
  end
end
