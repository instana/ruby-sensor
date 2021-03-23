# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # Describes the current process in terms of its existence inside of a Fargate container
    # @since 1.197.0
    class FargateProcess
      ID = 'com.instana.plugin.process'.freeze

      def initialize(metadata_uri: ENV['ECS_CONTAINER_METADATA_URI'])
        @metadata_uri = URI(metadata_uri)
        @client = Backend::RequestClient.new(@metadata_uri.host, @metadata_uri.port, use_ssl: @metadata_uri.scheme == "https")
        @start_time = Time.now
      end

      def entity_id
        Process.pid.to_s
      end

      def data
        proc_table = Sys::ProcTable.ps(pid: Process.pid)
        process = Backend::ProcessInfo.new(proc_table)

        {
          pid: process.pid.to_i,
          env: ENV.to_h,
          exec: process.name,
          args: process.arguments,
          user: process.uid,
          group: process.gid,
          start: @start_time.to_i * 1000,
          containerType: 'docker',
          container: container_id,
          "com.instana.plugin.host.name": task_id
        }
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      private

      def lookup(resource = nil)
        path = resource ? @metadata_uri.path + resource : @metadata_uri.path
        response = @client.send_request('GET', path)

        raise "Unable to get `#{path}`. Got `#{response.code}`." unless response.ok?

        response.json
      end

      def container_id
        @container_id ||= lookup['DockerId']
      end

      def task_id
        @task_id ||= lookup('/task')['TaskARN']
      end
    end
  end
end
