ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"

require 'rubygems'
require 'bundler/setup'
require Dir.pwd + '/test/jobs/sidekiq_job_1'

ENV["RACK_ENV"] = "test"
ENV["INSTANA_GEM_TEST"] = "true"

Bundler.require(:default, :test)

ENV['I_REDIS_URL'] ||= 'redis://127.0.0.1:6379'
Sidekiq.configure_server do |config|
  config.redis = { :url => ENV['I_REDIS_URL'] }
end
