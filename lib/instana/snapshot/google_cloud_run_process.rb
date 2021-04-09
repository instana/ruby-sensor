# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # @since 1.199.0
    class GoogleCloudRunProcess
      ID = 'com.instana.plugin.process'.freeze

      def initialize(metadata_uri: 'http://metadata.google.internal/')
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
          containerType: 'gcpCloudRunInstance',
          container: lookup('/computeMetadata/v1/instance/id'),
          "com.instana.plugin.host.name": "gcp:cloud-run:revision:#{ENV['K_REVISION']}"
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

      def lookup(resource)
        path = @metadata_uri.path + resource
        response = @client.send_request('GET', path)

        raise "Unable to get `#{path}`. Got `#{response.code}`." unless response.ok?

        response.body
      end
    end
  end
end
