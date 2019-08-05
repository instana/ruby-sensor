# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'instana/version'

Gem::Specification.new do |spec|
  spec.name          = "instana"
  spec.version       = Instana::VERSION
  spec.authors       = ["Peter Giacomo Lombardo"]
  spec.email         = ["pglombardo@gmail.com"]

  spec.summary       = %q{Ruby Distributed Tracing & Metrics Sensor for Instana}
  spec.description   = %q{The Instana gem collects and reports Ruby metrics and distibuted traces to your Instana dashboard.}
  spec.homepage      = "https://www.instana.com/"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.test_files    = Dir.glob("{test}/**/*.rb")

  spec.required_ruby_version = '>= 2.1'

  spec.licenses      = ['MIT']

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  # Development debugging
  # spec.add_development_dependency('byebug', '>= 8.0.0')
  spec.add_development_dependency('pry', '>= 0.10.0')
  # spec.add_development_dependency('pry-byebug', '>= 3.0.0')

  spec.add_runtime_dependency('sys-proctable', '>= 0.9.2')
  spec.add_runtime_dependency('get_process_mem', '>= 0.2.1')
  spec.add_runtime_dependency('timers', '>= 4.0.0')
  # spec.add_runtime_dependency('oj', '>=3.0.11')

  # Indirect dependency
  # https://github.com/instana/ruby-sensor/issues/10
  spec.add_runtime_dependency('ffi', '>=1.0.11')
end
