# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gat/version'

Gem::Specification.new do |spec|
  spec.name          = 'gat'
  spec.version       = Gat::VERSION
  spec.authors       = ['Ved Knom']
  spec.email         = ['vedknom@gmail.com']
  spec.description   = 'Gat is a tool for continuous commit in Git'
  spec.summary       = spec.description
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'thor', '~> 0.19.1'
  spec.add_runtime_dependency 'git', '~> 1.2.9'
end
