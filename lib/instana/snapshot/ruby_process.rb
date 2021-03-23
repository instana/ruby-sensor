# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # Describes the current Ruby process
    # @since 1.197.0
    class RubyProcess
      ID = 'com.instana.plugin.ruby'.freeze

      def initialize(pid: Process.pid)
        @pid = pid
      end

      def entity_id
        @pid.to_s
      end

      def data
        metrics_data.merge(Util.take_snapshot)
      end

      def snapshot
        {
          name: ID,
          entityId: entity_id,
          data: data
        }
      end

      private

      def metrics_data
        proc_table = Sys::ProcTable.ps(pid: Process.pid)
        process = Backend::ProcessInfo.new(proc_table)

        {
          pid: @pid,
          name: Util.get_app_name,
          exec_args: process.arguments,
          gc: Backend::GCSnapshot.instance.report,
          thread: {count: ::Thread.list.count},
          memory: {rss_size: proc_table.rss / 1024} # Bytes to Kilobytes
        }
      end
    end
  end
end
