# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'net/http'
require 'delegate'
require 'json'

# :nocov:
begin
  require 'oj'
  INSTANA_USE_OJ = true
rescue LoadError => _e
  Instana.logger.warn("Unable to load Oj.")
  INSTANA_USE_OJ = false
end
# :nocov:

module Instana
  module Backend
    # Convince wrapper around {Net::HTTP}.
    # @since 1.197.0
    class RequestClient
      attr_reader :host, :port

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
        timeout = Integer(ENV.fetch('INSTANA_TIMEOUT', 500))
        @host = host
        @port = port
        @use_ssl = use_ssl
        @timeout = timeout
        @client_mutex = Mutex.new
        @client = nil
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
        begin
          response = @client_mutex.synchronize do
            ensure_connection
            @client.send_request(method, path, body, headers)
          end
          Response.new(response)
        rescue Errno::ECONNREFUSED => e
          Instana.logger.debug("Connection refused to #{@host}:#{@port} - #{e.message}")
          create_error_response('503', 'Connection Refused', 'Connection refused', e.message)
        rescue Errno::EHOSTUNREACH => e
          Instana.logger.debug("Host unreachable #{@host}:#{@port} - #{e.message}")
          create_error_response('503', 'Host Unreachable', 'Host unreachable', e.message)
        rescue Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout => e
          Instana.logger.debug("Timeout connecting to #{@host}:#{@port} - #{e.message}")
          create_error_response('408', 'Request Timeout', 'Timeout', e.message)
        rescue SocketError => e
          Instana.logger.debug("Socket error connecting to #{@host}:#{@port} - #{e.message}")
          create_error_response('502', 'Socket Error', 'Socket error', e.message)
        rescue IOError => e
          Instana.logger.debug("IO error sending request to #{@host}:#{@port} - #{e.message}")
          # Reset connection on IO errors and retry once
          @client_mutex.synchronize { reset_connection }
          create_error_response('500', 'IO Error', 'IOError', e.message)
        rescue StandardError => e
          Instana.logger.debug("Error sending request to #{@host}:#{@port} - #{e.class}: #{e.message}")
          create_error_response('500', 'Internal Error', e.class.to_s, e.message)
        end
      end

      private

      def ensure_connection
        return if @client && !@client.instance_variable_get(:@socket).nil?

        reset_connection
        @client = Net::HTTP.start(@host, @port, use_ssl: @use_ssl, read_timeout: @timeout)
      end

      def reset_connection
        @client&.finish rescue nil
        @client = nil
      end

      def encode_body(data)
        # :nocov:
        INSTANA_USE_OJ ? Oj.dump(data, mode: :strict) : JSON.dump(data)
        # :nocov:
      end

      def create_error_response(code, message, error_type, error_message)
        # Create a mock response object that behaves like Net::HTTPResponse
        error_response = Object.new
        error_body = JSON.dump(error: error_type, message: error_message)

        error_response.define_singleton_method(:code) { code }
        error_response.define_singleton_method(:message) { message }
        error_response.define_singleton_method(:body) { error_body }
        error_response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPResponse || super(klass) }

        Response.new(error_response)
      end
    end
  end
end
