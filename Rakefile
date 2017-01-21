require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []

  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']

  case File.basename(ENV['BUNDLE_GEMFILE']).split('.').first
  when /rails50/
    t.test_files = FileList['test/frameworks/rails/activerecord5_test.rb']
    t.test_files = FileList['test/frameworks/rails/actioncontroller_test.rb']
  when /rails42/
    t.test_files = FileList['test/frameworks/rails/activerecord4_test.rb']
    t.test_files = FileList['test/frameworks/rails/actioncontroller_test.rb']
  when /rails32/
    t.test_files = FileList['test/frameworks/rails/activerecord3_test.rb']
    t.test_files = FileList['test/frameworks/rails/actioncontroller_test.rb']
  when /libraries/
    t.test_files = FileList['test/instrumentation/*_test.rb']
  else
    t.test_files = FileList['test/agent/*_test.rb'] +
                   FileList['test/tracing/*_test.rb'] +
                   FileList['test/profiling/*_test.rb']
  end
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
