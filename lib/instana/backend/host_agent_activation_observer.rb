# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # Process which is responsible for initiating monitoring of a Ruby program with a local agent.
    # @since 1.197.0
    class HostAgentActivationObserver
      DISCOVERY_URL = '/com.instana.plugin.ruby.discovery'.freeze
      ENTITY_DATA_URL = '/com.instana.plugin.ruby.%i'.freeze
      class DiscoveryError < StandardError; end

      # @param [RequestClient] client used to make requests to the backend
      # @param [Concurrent::Atom] discovery object used to store discovery response in
      def initialize(client, discovery, wait_time: 30, logger: ::Instana.logger, max_wait_tries: 60, proc_table: Sys::ProcTable, socket_proc: default_socket_proc) # rubocop:disable Metrics/ParameterLists
        @client = client
        @discovery = discovery
        @wait_time = wait_time
        @logger = logger
        @max_wait_tries = max_wait_tries
        @proc_table = proc_table
        @socket_proc = socket_proc
      end

      def update(_time, _old_version, new_version)
        return unless new_version.nil?

        socket = @socket_proc.call(@client)

        try_forever_with_backoff do
          payload = discovery_payload(socket)
          discovery_response = @client.send_request('PUT', DISCOVERY_URL, payload)

          raise DiscoveryError, "Discovery response was #{discovery_response.code} with `#{payload}`." unless discovery_response.ok?

          discovery = discovery_response.json
          raise DiscoveryError, "Expected discovery to be a Hash, not a `#{discovery.class}`." unless discovery.is_a?(Hash)

          @logger.debug("Discovery complete (`#{discovery}`). Waiting for agent.")
          wait_for_backend(discovery['pid'])
          @logger.debug("Agent ready.")
          @discovery.swap { discovery }
        end

        socket.close
      end

      private

      def discovery_payload(socket)
        proc_table = @proc_table.ps(pid: Process.pid)
        process = ProcessInfo.new(proc_table)

        payload = {
          name: process.name,
          args: process.arguments,
          pid: process.parent_pid,
          pidFromParentNS: process.from_parent_namespace,
          cpuSetFileContent: process.cpuset
        }

        inode_path = "/proc/self/fd/#{socket.fileno}"
        if socket.fileno && File.exist?(inode_path)
          payload[:fd] = socket.fileno
          payload[:inode] = File.readlink(inode_path)
        end

        payload.compact
      end

      def wait_for_backend(pid)
        response = @max_wait_tries.times do
          path = format(ENTITY_DATA_URL, pid)
          wait_response = @client.send_request('HEAD', path)

          break(wait_response) if wait_response.ok?

          sleep(1)
        end

        raise DiscoveryError, "The backend didn't respond in time." unless response.is_a?(RequestClient::Response) && response.ok?
      end

      def try_forever_with_backoff
        yield
      rescue DiscoveryError, Net::OpenTimeout => e
        @logger.debug(e)
        sleep(@wait_time)
        retry
      rescue StandardError => e
        @logger.error(%(#{e}\n#{e.backtrace.join("\n")}))
      end

      def default_socket_proc
        ->(c) { TCPSocket.new(c.host, c.port) }
      end
    end
  end
end
