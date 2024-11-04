# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'bundler/gem_tasks'
require 'rake/testtask'

require 'json'

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = ["--parser=parse.y"] if Gem::Version.new(RUBY_VERSION) > Gem::Version.new('3.3')

  t.libs << "test"
  t.libs << "lib"

  if ENV['APPRAISAL_INITIALIZED']
    appraised_group = File.basename(ENV['BUNDLE_GEMFILE']).split(/_[0-9]+\./).first
    suite_files = FileList['test/{instrumentation,frameworks}/*_test.rb']

    t.test_files = suite_files.select { |f| File.basename(f).start_with?(appraised_group) }
  else
    t.test_files = FileList[
      'test/*_test.rb',
      'test/{agent,tracing,backend,snapshot}/*_test.rb'
    ]
  end
end

namespace :coverage do
  task :merge_reports do
    require 'simplecov'
    require 'simplecov_json_formatter'

    SimpleCov.start do
      enable_coverage :branch
      SimpleCov.collate Dir["partial_coverage_results/.resultset-*.json"] do
        formatter SimpleCov::Formatter::MultiFormatter.new(
          [
            SimpleCov::Formatter::SimpleFormatter,
            SimpleCov::Formatter::JSONFormatter
          ]
        )
      end
    end
  end
end

task :default => :test
