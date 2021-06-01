# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # Describes a Docker container visible to the current process
    # @since 1.197.0
    class DockerContainer
      include Deltable
      ID = 'com.instana.plugin.docker'.freeze

      def initialize(container, metadata_uri: ENV['ECS_CONTAINER_METADATA_URI'])
        @container = container
        @metadata_uri = URI(metadata_uri)
        @client = Backend::RequestClient.new(@metadata_uri.host, @metadata_uri.port, use_ssl: @metadata_uri.scheme == "https")
      end

      def entity_id
        "#{@container['Labels']['com.amazonaws.ecs.task-arn']}::#{@container['Name']}"
      end

      def data
        metrics = lookup('/task/stats').fetch(@container['DockerId'], {})

        container_metrics(metrics)
          .merge(container_metadata)
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      private

      def container_metadata
        {
          Id: @container['DockerId'],
          Created: @container['CreatedAt'],
          Started: @container['StartedAt'],
          Image: @container['Image'],
          Labels: @container['Labels'],
          Ports: @container['Ports'],
          NetworkMode: @container['Networks'].first['NetworkMode']
        }
      end

      def container_metrics(metrics)
        return {} if metrics.empty?

        {
          memory: memory_stats(metrics),
          blkio: blkio_stats(metrics),
          cpu: cpu_stats(metrics),
          network: network_stats(metrics)
        }.reject { |_, v| v.nil? }
      end

      def memory_stats(metrics)
        identity = ->(_old, new) { new }

        {
          active_anon: delta('memory_stats', 'stats', 'active_anon', compute: identity, obj: metrics),
          active_file: delta('memory_stats', 'stats', 'active_file', compute: identity, obj: metrics),
          inactive_anon: delta('memory_stats', 'stats', 'inactive_anon', compute: identity, obj: metrics),
          inactive_file: delta('memory_stats', 'stats', 'inactive_file', compute: identity, obj: metrics),
          total_cache: delta('memory_stats', 'stats', 'total_cache', compute: identity, obj: metrics),
          total_rss: delta('memory_stats', 'stats', 'total_rss', compute: identity, obj: metrics),
          usage: delta('memory_stats', 'usage', compute: identity, obj: metrics),
          max_usage: delta('memory_stats', 'max_usage', compute: identity, obj: metrics),
          limit: delta('memory_stats', 'limit', compute: identity, obj: metrics)
        }
      end

      def blkio_stats(metrics)
        delta = ->(old, new) { new - old }
        bytes = {
          'block_bytes' => metrics['blkio_stats']['io_service_bytes_recursive'].map { |r| [r['op'], r['value']] }.to_h
        }

        {
          blk_read: delta('block_bytes', 'Read', compute: delta, obj: bytes),
          blk_write: delta('block_bytes', 'Write', compute: delta, obj: bytes)
        }
      end

      def cpu_stats(metrics)
        delta = ->(old, new) { new - old }
        identity = ->(_old, new) { new }

        cpu_system_delta = delta('cpu_stats', 'system_cpu_usage', compute: delta, obj: metrics).to_f
        online_cpus = delta('cpu_stats', 'online_cpus', compute: identity, obj: metrics) || 1

        {
          total_usage: (delta('cpu_stats', 'cpu_usage', 'total_usage', compute: delta, obj: metrics) / cpu_system_delta) * online_cpus,
          user_usage: (delta('cpu_stats', 'cpu_usage', 'usage_in_usermode', compute: delta, obj: metrics) / cpu_system_delta) * online_cpus,
          system_usage: (delta('cpu_stats', 'cpu_usage', 'usage_in_kernelmode', compute: delta, obj: metrics) / cpu_system_delta) * online_cpus,
          throttling_count: delta('cpu_stats', 'throttling_data', 'periods', compute: delta, obj: metrics),
          throttling_time: delta('cpu_stats', 'throttling_data', 'throttled_time', compute: delta, obj: metrics)
        }
      end

      def network_stats(metrics)
        delta = ->(old, new) { new - old }
        return nil unless metrics['networks']

        interfaces = metrics['networks'].keys
        payload = {
          rx: {
            bytes: 0,
            dropped: 0,
            errors: 0,
            packet: 0
          },
          tx: {
            bytes: 0,
            dropped: 0,
            errors: 0,
            packet: 0
          }
        }

        interfaces.each do |interface|
          payload[:rx][:bytes] += delta('networks', interface, 'rx_bytes', compute: delta, obj: metrics)
          payload[:rx][:dropped] += delta('networks', interface, 'rx_dropped', compute: delta, obj: metrics)
          payload[:rx][:errors] += delta('networks', interface, 'rx_errors', compute: delta, obj: metrics)
          payload[:rx][:packet] += delta('networks', interface, 'rx_packets', compute: delta, obj: metrics)

          payload[:tx][:bytes] += delta('networks', interface, 'tx_bytes', compute: delta, obj: metrics)
          payload[:tx][:dropped] += delta('networks', interface, 'tx_packets', compute: delta, obj: metrics)
          payload[:tx][:errors] += delta('networks', interface, 'tx_errors', compute: delta, obj: metrics)
          payload[:tx][:packet] += delta('networks', interface, 'tx_dropped', compute: delta, obj: metrics)
        end

        payload
      end

      def lookup(resource)
        path = @metadata_uri.path + resource
        response = @client.send_request('GET', path)

        raise "Unable to get `#{path}`. Got `#{response.code}`." unless response.ok?

        response.json
      end
    end
  end
end
