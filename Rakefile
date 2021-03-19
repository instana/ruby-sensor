# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'bundler/gem_tasks'
require 'rake/testtask'

require 'json'

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []

  t.libs << "test"
  t.libs << "lib"
 
  if ENV['APPRAISAL_INITIALIZED']
    appraised_group = File.basename(ENV['BUNDLE_GEMFILE']).split(/_[0-9]+\./).first
    suite_files = Dir['test/{instrumentation,frameworks}/*_test.rb']
        
    t.test_files = suite_files.select { |f| File.basename(f).start_with?(appraised_group) }
  else
    t.test_files = Dir[
      'test/*_test.rb',
      'test/{agent,tracing,backend}/*_test.rb'
    ]
  end
end

task :default => :test
