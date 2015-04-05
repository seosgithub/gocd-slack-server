# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gocdss/version'

Gem::Specification.new do |spec|
  spec.name          = "gocd-slack-server"
  spec.version       = Gocdss::VERSION
  spec.authors       = ["Seo Townsend"]
  spec.email         = ["seotownsend@icloud.com"]
  spec.summary       = %q{This is a standalone server that relays gocd information directly to slack}
  spec.description   = %q{It is not a gocd plugin, it uses Gocd's API to relay information}
  spec.homepage      = "https://github.com/sotownsend/gocd-slack-server"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.3"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_runtime_dependency "thor", "~> 0.19"
  spec.add_runtime_dependency "ghee", "~> 0.12.17"
  spec.add_runtime_dependency "octokit", "~> 3.0"
  spec.add_runtime_dependency "git", "~> 1.2.9.1"
end
