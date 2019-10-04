require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []

  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']

  if ENV.key?('BUNDLE_GEMFILE')
    case File.basename(ENV['BUNDLE_GEMFILE']).split('.').first
    when /rails50/
      t.test_files = %w(test/frameworks/rails/activerecord_test.rb
                        test/frameworks/rails/actioncontroller_test.rb
                        test/frameworks/rails/actionview5_test.rb)
    when /rails42/
      t.test_files = %w(test/frameworks/rails/activerecord_test.rb
                        test/frameworks/rails/actioncontroller_test.rb
                        test/frameworks/rails/actionview4_test.rb)
    when /rails32/
      t.test_files = %w(test/frameworks/rails/activerecord_test.rb
                        test/frameworks/rails/actioncontroller_test.rb
                        test/frameworks/rails/actionview3_test.rb)
    when /libraries/
      t.test_files = FileList['test/instrumentation/*_test.rb',
                              'test/frameworks/cuba_test.rb',
                              'test/frameworks/rack_test.rb',
                              'test/frameworks/roda_test.rb',
                              'test/frameworks/sinatra_test.rb']
    else
      t.test_files = FileList['test/agent/*_test.rb'] +
                     FileList['test/tracing/*_test.rb'] +
                     FileList['test/profiling/*_test.rb'] +
                     FileList['test/benchmarks/bench_*.rb']
    end
  else
    t.test_files = FileList['test/agent/*_test.rb'] +
        FileList['test/tracing/*_test.rb'] +
        FileList['test/profiling/*_test.rb'] +
        FileList['test/benchmarks/bench_*.rb']
  end
end

task :environment do
  ENV['INSTANA_DEBUG'] = 'true'
  Bundler.require(:default, :development)
end

task :console => :environment do
  ARGV.clear
  Pry.start
end

task :default => :spec
