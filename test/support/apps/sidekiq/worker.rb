# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'sidekiq/launcher'
require 'sidekiq/cli'
require 'sidekiq/api'
require 'sidekiq/processor'

require_relative 'jobs/sidekiq_job_1'
require_relative 'jobs/sidekiq_job_2'

::Instana.logger.info "Booting instrumented sidekiq worker for tests."
::Sidekiq.logger.level = ::Logger::FATAL

properties = {queues: ['important'], concurrency: 2}

sidekiq_version = Gem::Specification.find_by_name('sidekiq').version
config_or_options =
  if sidekiq_version >= Gem::Version.new('7.0.0')
    ::Sidekiq::Config.new(Sidekiq.default_configuration.merge!(properties))
  else
    ::Sidekiq.options.merge(properties)
  end

sidekiq_thread = Thread.new do
  launcher = ::Sidekiq::Launcher.new(
    config_or_options
  )
  launcher.run
  Thread.current[:worker] = launcher
end

Minitest.after_run do
  ::Instana.logger.info "Killing Sidekiq worker"
  sidekiq_thread[:worker].stop
  sleep 1
end
