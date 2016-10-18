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
  Bundler.require(:default, :development)
end

task :console => :environment do
  ARGV.clear
  Pry.start
end

task :default => :spec
