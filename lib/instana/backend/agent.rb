# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # Wrapper class around the various transport backends
    # @since 1.197.0
    class Agent
      attr_reader :delegate

      def initialize(fargate_metadata_uri: ENV['ECS_CONTAINER_METADATA_URI'], logger: ::Instana.logger)
        @delegate = nil
        @logger = logger
        @fargate_metadata_uri = fargate_metadata_uri
      end

      def setup
        @delegate = if ENV.key?('_HANDLER')
                      ServerlessAgent.new([Snapshot::LambdaFunction.new])
                    elsif ENV.key?('K_REVISION') && ENV.key?('INSTANA_ENDPOINT_URL')
                      ServerlessAgent.new([
                                            Snapshot::GoogleCloudRunProcess.new,
                                            Snapshot::GoogleCloudRunInstance.new,
                                            Snapshot::RubyProcess.new
                                          ])
                    elsif @fargate_metadata_uri && ENV.key?('INSTANA_ENDPOINT_URL')
                      ServerlessAgent.new(fargate_snapshots)
                    else
                      HostAgent.new
                    end

        @delegate.setup
      end

      def method_missing(mth, *args, **kwargs, &block)
        if @delegate.respond_to?(mth)
          @delegate.public_send(mth, *args, **kwargs, &block)
        else
          super(mth, *args, **kwargs, &block)
        end
      end

      def respond_to_missing?(mth, include_all = false)
        @delegate.respond_to?(mth, include_all)
      end

      private

      def fargate_snapshots
        metadata_uri = URI(@fargate_metadata_uri)
        client = Backend::RequestClient.new(metadata_uri.host, metadata_uri.port, use_ssl: metadata_uri.scheme == "https")
        response = client.send_request('GET', "#{metadata_uri.path}/task")

        if response.ok?
          docker = response
                   .json['Containers']
                   .map { |c| [Snapshot::DockerContainer.new(c), Snapshot::FargateContainer.new(c)] }
                   .flatten

          docker + [Snapshot::FargateProcess.new, Snapshot::RubyProcess.new, Snapshot::FargateTask.new]
        else
          @logger.warn("Received #{response.code} when requesting containers.")
          []
        end
      end
    end
  end
end
