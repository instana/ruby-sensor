# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # Describes the current process in terms of its existence inside of a Fargate task
    # @since 1.197.0
    class FargateTask
      ID = 'com.instana.plugin.aws.ecs.task'.freeze

      def initialize(metadata_uri: ENV['ECS_CONTAINER_METADATA_URI'])
        @metadata_uri = URI(metadata_uri)
        @client = Backend::RequestClient.new(@metadata_uri.host, @metadata_uri.port, use_ssl: @metadata_uri.scheme == "https")
      end

      def entity_id
        task_metadata['TaskARN']
      end
      alias host_name entity_id

      def data
        {
          taskArn: task_metadata['TaskARN'],
          clusterArn: task_metadata['Cluster'],
          taskDefinition: task_metadata['Family'],
          taskDefinitionVersion: task_metadata['Revision'],
          availabilityZone: task_metadata['AvailabilityZone'],
          desiredStatus: task_metadata['DesiredStatus'],
          knownStatus: task_metadata['KnownStatus'],
          pullStartedAt: task_metadata['PullStartedAt'],
          pullStoppedAt: task_metadata['PullStoppedAt'],
          instanaZone: instana_zone,
          tags: instana_tags
        }.reject { |_, v| v.nil? }
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      private

      def task_metadata
        lookup('/task')
      end

      def instana_zone
        ENV['INSTANA_ZONE']
      end

      def instana_tags
        ENV.fetch('INSTANA_TAGS', '')
           .split(/,/)
           .map { |t| t.include?('=') ? t.split('=', 2) : [t, nil] }
           .to_h
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
