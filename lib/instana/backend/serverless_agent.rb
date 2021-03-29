# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # @since 1.197.0
    class ServerlessAgent
      DEFAULT_SECRETS = 'contains-ignore-case:key,password,secret'.freeze
      attr_reader :timer

      # rubocop:disable Metrics/ParameterLists
      def initialize(snapshots,
                     timer_class: Concurrent::TimerTask,
                     processor: ::Instana.processor,
                     logger: ::Instana.logger,
                     backend_uri: ENV['INSTANA_ENDPOINT_URL'],
                     secrets: ENV.fetch('INSTANA_SECRETS', DEFAULT_SECRETS), headers: ENV.fetch('INSTANA_EXTRA_HTTP_HEADERS', ''))
        @snapshots = snapshots
        @processor = processor
        @logger = logger
        @timer = timer_class.new(execution_interval: 1, run_now: true) { send_bundle }
        @backend_uri = URI(backend_uri)
        @client = Backend::RequestClient.new(@backend_uri.host, @backend_uri.port, use_ssl: @backend_uri.scheme == "https")
        @secrets = secrets
        @headers = headers
      end
      # rubocop:enable Metrics/ParameterLists

      def setup; end

      def spawn_background_thread
        @timer.execute
      end

      # @return [Boolean] true if the agent able to send spans to the backend
      def ready?
        true
      end

      # @return [Hash, NilClass] the backend friendly description of the current in process collector
      def source
        return @source if @source

        snapshot = @snapshots.detect { |s| s.respond_to?(:source) }

        if snapshot
          @source = snapshot.source
        else
          @logger.warn('Unable to find a snapshot which provides a source.')
          {}
        end
      end

      # @return [Array] extra headers to include in the trace
      def extra_headers
        @headers.split(';')
      end

      # @return [Hash] values which are removed from urls sent to the backend
      def secret_values
        # TODO: Parse from env
        matcher, *keys = @secrets.split(/[:,]/)
        {'matcher' => matcher, 'list' => keys}
      end

      private

      def request_headers
        {
          'X-Instana-Host' => host_name,
          'X-Instana-Key' => ENV['INSTANA_AGENT_KEY'],
          'X-Instana-Time' => (Time.now.to_i * 1000).to_s
        }
      end

      def send_bundle
        spans = @processor.queued_spans
        bundle = {
          spans: spans,
          metrics: {
            plugins: agent_snapshots
          }
        }

        path = "#{@backend_uri.path}/bundle"
        response = @client.send_request('POST', path, bundle, request_headers)

        return if response.ok?

        @logger.warn("Recived a `#{response.code}` when sending data.")
      end

      def agent_snapshots
        @snapshots.map do |snapshot|
          begin
            snapshot.snapshot
          rescue StandardError => e
            @logger.error(e.message)
            nil
          end
        end.compact
      end

      def host_name
        return @host_name if @host_name

        snapshot = @snapshots.detect { |s| s.respond_to?(:host_name) }

        if snapshot
          @host_name = snapshot.host_name
        else
          @logger.warn('Unable to find a snapshot which provides a host_name.')
          ''
        end
      end
    end
  end
end
