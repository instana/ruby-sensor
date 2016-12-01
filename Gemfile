source 'https://rubygems.org'

group :development, :test do
  gem 'rake'
  gem 'minitest', '5.9.1'
  gem 'minitest-reporters'
  gem 'minitest-debugger', :require => false
  gem 'rack-test'
  gem 'webmock'

  # Frameworks
  gem "sinatra", '1.4.7'
  gem "cuba"
  gem "roda"

  # Webservers
  gem "puma"

  # Rack v2 dropped support for Ruby 2.2 and higher.
  if RUBY_VERSION < '2.2'
    gem 'rack', '< 2.0'
  end
end

group :development do
  gem 'ruby-debug',   :platforms => [:mri_18, :jruby]
  gem 'debugger',     :platform  =>  :mri_19
  gem 'byebug',       :platforms => [:mri_20, :mri_21, :mri_22, :mri_23]
  if RUBY_VERSION > '1.8.7'
    gem 'pry'
    gem 'pry-byebug', :platforms => [:mri_20, :mri_21, :mri_22, :mri_23]
  else
    gem 'pry', '0.9.12.4'
  end
end

gem 'get_process_mem'
gem 'sys-proctable'
gem 'timers'

# instana.gemspec
gemspec
