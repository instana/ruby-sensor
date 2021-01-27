source 'https://rubygems.org'

group :development, :test do
  gem 'rake'
  gem 'minitest', '5.9.1'
  gem 'minitest-reporters'
  gem 'minitest-debugger', :require => false
  gem 'webmock'
  gem 'puma'

  # Rack v2 dropped support for Ruby 2.2 and higher.
  if RUBY_VERSION < '2.2'
    gem 'rack', '~> 1.6'
  end
  gem 'rack-test'

  # public_suffix dropped support for Ruby 2.1 and earlier.
  gem 'public_suffix', '< 3.0'
end

gem 'simplecov', '~> 0.21.2'

# instana.gemspec
gemspec
