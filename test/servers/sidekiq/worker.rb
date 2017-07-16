require 'sidekiq/launcher'
require 'sidekiq/cli'
require 'sidekiq/api'
require 'sidekiq/processor'

require Dir.pwd + '/test/jobs/sidekiq_job_1.rb'
require Dir.pwd + '/test/jobs/sidekiq_job_2.rb'

::Instana.logger.info "Booting instrumented sidekiq worker for tests."
::Sidekiq.logger.level = ::Logger::FATAL

sidekiq_thread = Thread.new do
  launcher = ::Sidekiq::Launcher.new(
    ::Sidekiq.options.merge(
      queues: ['important'],
      concurrency: 2
    )
  )
  launcher.run
  Thread.current[:worker] = launcher
end

Minitest.after_run do
  ::Instana.logger.info "Killing Sidekiq worker"
  sidekiq_thread[:worker].stop
  sleep 2
end

sleep 5
# Sidekiq's server checking. If CLI constant is available, sidekiq treats
# current thread is in server mode, which is not we are expecting
::Sidekiq.send(:remove_const, :CLI)
