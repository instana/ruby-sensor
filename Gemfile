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

group :development do
  # gem 'ruby-debug',   :platforms => [:mri_18, :jruby]
  # gem 'debugger',     :platform  =>  :mri_19
  # gem 'stackprof'

  # if RUBY_VERSION > '1.8.7'
  #   gem 'pry'

  #   if RUBY_VERSION < '2.2'
  #     gem 'byebug', '< 9.1.0'
  #     gem 'pry-byebug'
  #   else
  #     gem 'pry-byebug'
  #   end
  # else
  #   gem 'pry', '0.9.12.4'
  # end
end

# instana.gemspec
gemspec
