# -*- encoding: utf-8 -*-
require File.expand_path('../lib/inferx/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Takahiro Kondo"]
  gem.email         = ["kondo@atedesign.net"]
  gem.description   = %q{It is Naive Bayes classifier, and the training data is kept always by Redis.}
  gem.summary       = %q{Naive Bayes classifier, the training data on Redis}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "inferx"
  gem.require_paths = ["lib"]
  gem.version       = Inferx::VERSION

  gem.add_runtime_dependency 'redis'

  gem.add_development_dependency 'rspec'
end
