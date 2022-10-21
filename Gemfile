# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

source 'https://rubygems.org'

gem 'rake'
gem 'minitest', '5.9.1'
gem 'minitest-reporters'
gem 'webmock'
gem 'puma'

gem 'rubocop', '~> 1.9'

# Rack v2 dropped support for Ruby 2.2 and higher.
if RUBY_VERSION < '2.2'
  gem 'rack', '<3.0.0', '~> 1.6'
else
  gem 'rack', '<3.0.0'
  # gem 'rackup'
end
gem 'rack-test'

gem 'simplecov', '~> 0.21.2'

# instana.gemspec
gemspec
