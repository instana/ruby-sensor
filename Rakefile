require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []

  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :environment do
  ENV['INSTANA_GEM_DEV'] = 'true'
  Bundler.require(:default, :development)
end

task :console => :environment do
  # Possible debug levels: :agent, :agent_comm, :trace, :agent_response, :tracing
  # ::Instana.logger.debug_level = [ :agent, :agent_comm ]
  ARGV.clear
  Pry.start
end

task :default => :spec
