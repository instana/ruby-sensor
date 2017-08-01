# This is a helper initializer to boot a local instrumented Sidekiq stack
# for development and testing.
#
# export BUNDLE_GEMFILE=/path/to/ruby-sensor/gemfiles/libraries.gemfile
# bundle install
# bundle exec sidekiq -c 2 -q important -r ./test/servers/helpers/sidekiq_worker_initializer.rb
#
# In another shell, you can boot a console to queue jobs:
#
# export BUNDLE_GEMFILE=/path/to/ruby-sensor/gemfiles/libraries.gemfile
# bundle install
# bundle exec rake console
# > Instana.tracer.start_or_continue_trace(:sidekiq_demo) do
# >  ::Sidekiq::Client.push( 'queue' => 'important', 'class' => ::SidekiqJobOne,
# >                          'args' => [1, 2, 3], 'retry' => false)
# > end
#

# Load test jobs.
require Dir.pwd + '/test/jobs/sidekiq_job_1.rb'
require Dir.pwd + '/test/jobs/sidekiq_job_2.rb'

require "sidekiq"
require "instana"
::Instana.logger.info "Booting instrumented sidekiq worker for tests."
::Sidekiq.logger.level = ::Logger::DEBUG
