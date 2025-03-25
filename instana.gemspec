# coding: utf-8

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'instana/version'

Gem::Specification.new do |spec|
  spec.name          = "instana"
  spec.version       = Instana::VERSION
  spec.authors       = ["Peter Giacomo Lombardo"]
  spec.email         = ["pglombardo@gmail.com"]

  spec.summary       = %q{Ruby Distributed Tracing & Metrics Sensor for Instana}
  spec.description   = %q{The Instana gem is a zero configuration tool that will automatically collect key metrics and distributed traces from your Ruby processes. Just install and go.}
  spec.homepage      = "https://www.instana.com/"

  spec.metadata = {
      "changelog_uri"     => "https://github.com/instana/ruby-sensor/releases",
      "documentation_uri" => "https://docs.instana.io/ecosystem/ruby/",
      "homepage_uri"      => "https://www.instana.com/",
      "source_code_uri"   => "https://github.com/instana/ruby-sensor",
  }

  spec.licenses      = ['MIT']
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.test_files    = Dir.glob("{test}/**/*.rb")

  spec.required_ruby_version = '>= 3.0'
  spec.platform      = defined?(JRUBY_VERSION) ? 'java' : Gem::Platform::RUBY

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "fakefs"
  spec.add_development_dependency "irb"
  spec.add_development_dependency "benchmark"

  spec.add_runtime_dependency('base64', '>= 0.1')
  spec.add_runtime_dependency('logger')
  spec.add_runtime_dependency('concurrent-ruby', '>= 1.1')
  spec.add_runtime_dependency('csv', '>= 0.1')
  spec.add_runtime_dependency('sys-proctable', '>= 1.2.2')
  spec.add_runtime_dependency('opentelemetry-api', '~> 1.4')
  spec.add_runtime_dependency('opentelemetry-common')
  spec.add_runtime_dependency('oj', '>=3.0.11') unless RUBY_PLATFORM =~ /java/i
end
