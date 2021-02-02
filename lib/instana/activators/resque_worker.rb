module Instana
  module Activators
    class ResqueWorker < Activator
      def can_instrument?
        defined?(::Resque::Worker) &&
          defined?(::Resque::Job) &&
          ::Instana.config[:'resque-worker'][:enabled]
      end

      def instrument
        require 'instana/instrumentation/resque'

        ::Resque::Worker.prepend(::Instana::Instrumentation::ResqueWorker)
        ::Resque::Job.prepend(::Instana::Instrumentation::ResqueJob)

        ::Resque.before_fork do |_job|
          ::Instana.agent.before_resque_fork
        end
        ::Resque.after_fork do |_job|
          ::Instana.agent.after_resque_fork
        end

        # Set this so we assure that any remaining collected traces are reported at_exit
        ENV['RUN_AT_EXIT_HOOKS'] = "1"

        true
      end
    end
  end
end
