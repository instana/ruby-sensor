# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'instana/version'

Gem::Specification.new do |spec|
  spec.name          = "instana"
  spec.version       = Instana::VERSION
  spec.authors       = ["Peter Giacomo Lombardo"]
  spec.email         = ["pglombardo@gmail.com"]

  spec.summary       = %q{Ruby sensor for Instana}
  spec.description   = %q{Provides Ruby sensor instrumentation for Instana.}
  spec.homepage      = "https://www.instana.com/"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  #if spec.respond_to?(:metadata)
  #  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  #else
  #  raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  #end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_runtime_dependency('sys-proctable', '>= 1.1.3')
  spec.add_runtime_dependency('get_process_mem', '>= 0.2.1')
  spec.add_runtime_dependency('timers', '>= 4.1.0')
end
