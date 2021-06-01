# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # @since 1.199
    class GoogleCloudRunInstance
      ID = 'com.instana.plugin.gcp.run.revision.instance'.freeze

      def initialize(metadata_uri: 'http://metadata.google.internal')
        @metadata_uri = URI(metadata_uri)
        @client = Backend::RequestClient.new(@metadata_uri.host, @metadata_uri.port, use_ssl: @metadata_uri.scheme == "https")
      end

      def entity_id
        lookup('/computeMetadata/v1/instance/id')
      end

      def data
        {
          runtime: 'ruby',
          region: gcp_region,
          service: ENV['K_SERVICE'],
          configuration: ENV['K_CONFIGURATION'],
          revision: ENV['K_REVISION'],
          instanceId: entity_id,
          port: ENV['PORT'],
          numericProjectId: lookup('/computeMetadata/v1/project/numeric-project-id'),
          projectId: lookup('/computeMetadata/v1/project/project-id')
        }.reject { |_, v| v.nil? }
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      def source
        {
          hl: true,
          cp: 'gcp',
          e: entity_id
        }
      end

      def host_name
        "gcp:cloud-run:revision:#{ENV['K_REVISION']}"
      end

      private

      def gcp_region
        lookup('/computeMetadata/v1/instance/zone').split('/').last
      end

      def lookup(resource)
        path = @metadata_uri.path + resource
        response = @client.send_request('GET', path, nil, {'Metadata-Flavor' => 'Google'})

        raise "Unable to get `#{path}`. Got `#{response.code}` `#{response['location']}`." unless response.ok?

        response.body
      end
    end
  end
end
