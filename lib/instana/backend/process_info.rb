# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # Wrapper around {Sys::ProcTable} that adds support for reading the /proc
    # file system for extra information around containers
    # @since 1.197.0
    class ProcessInfo < SimpleDelegator
      def name
        cmdline
          .split(' ').first
      end

      def arguments
        _, *arguments = cmdline.split(' ')
        clean_arguments(arguments)
      end

      def parent_pid
        if in_container? && sched_pid != pid
          sched_pid
        else
          pid
        end
      end

      def from_parent_namespace
        !in_container? || in_container? && sched_pid != pid
      end

      def cpuset
        path = "/proc/#{pid}/cpuset"
        return unless File.exist?(path)

        File.read(path).strip
      end

      def in_container?
        !cpuset.nil? && cpuset != '/'
      end

      def sched_pid
        path = '/proc/self/sched'
        return unless File.exist?(path)

        File.read(path).match(/\d+/).to_s.to_i
      end

      private

      def clean_arguments(arguments)
        return arguments unless RbConfig::CONFIG['host_os'].include?('darwin')

        arguments.reject do |a|
          if a.include?('=')
            k, = a.split('=', 2)
            ENV[k]
          end
        end
      end
    end
  end
end
