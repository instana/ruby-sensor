require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []

  t.libs << "test"
  t.libs << "lib"

  t.test_files = Dir[
    'test/*_test.rb',
    'test/{agent,tracing,profiling,benchmarks}/*_test.rb'
  ]

  case File.basename(ENV.fetch('BUNDLE_GEMFILE', '')).split('.').first
  when /rails6/
    t.test_files = %w(test/frameworks/rails/activerecord_test.rb
                      test/frameworks/rails/actioncontroller_test.rb
                      test/frameworks/rails/actionview5_test.rb)
  when /rails5/
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
    t.test_files = Dir['test/{instrumentation,frameworks}/*_test.rb']
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
