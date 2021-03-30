# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # Describes a Fargate container visible to the current process
    # @since 1.197.0
    class FargateContainer
      ID = 'com.instana.plugin.aws.ecs.container'.freeze

      def initialize(container, metadata_uri: ENV['ECS_CONTAINER_METADATA_URI'])
        @container = container
        @metadata_uri = URI(metadata_uri)
        @client = Backend::RequestClient.new(@metadata_uri.host, @metadata_uri.port, use_ssl: @metadata_uri.scheme == "https")
      end

      def entity_id
        "#{@container['Labels']['com.amazonaws.ecs.task-arn']}::#{@container['Name']}"
      end

      def data
        payload = {
          dockerId: @container['DockerId'],
          dockerName: @container['DockerName'],
          containerName: @container['Name'],
          image: @container['Image'],
          imageId: @container['ImageID'],
          taskArn: @container['Labels']['com.amazonaws.ecs.task-arn'],
          taskDefinition: @container['Labels']['com.amazonaws.ecs.task-definition-data.family'],
          taskDefinitionVersion: @container['Labels']['com.amazonaws.ecs.task-definition-data.version'],
          clusterArn: @container['Labels']['com.amazonaws.ecs.cluster'],
          desiredStatus: @container['DesiredStatus'],
          knownStatus: @container['KnownStatus'],
          ports: @container['Ports'],
          limits: {
            cpu: @container['Limits']['CPU'],
            memory: @container['Limits']['Memory']
          },
          createdAt: @container['CreatedAt'],
          startedAt: @container['StartedAt']
        }

        if current_container?
          payload[:instrumented] = true
          payload[:runtime] = 'ruby'
        end

        payload
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      def source
        return unless current_container?

        {
          hl: true,
          cp: 'aws',
          e: entity_id
        }
      end

      private

      def current_container?
        return @current_container if @current_container

        current_conatiner_response = current_conatiner
        @current_container = @container['DockerName'] == current_conatiner_response['DockerName']
      end

      def current_conatiner
        path = @metadata_uri.path
        response = @client.send_request('GET', path)

        raise "Unable to get `#{path}`. Got `#{response.code}`." unless response.ok?

        response.json
      end
    end
  end
end
