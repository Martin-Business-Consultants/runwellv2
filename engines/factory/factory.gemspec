require_relative "lib/factory/version"

Gem::Specification.new do |spec|
  spec.name = "factory"
  spec.version = Factory::VERSION
  spec.summary = "Hands ready work to AI agents on runners, and tracks every run, as a Runwell plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-factory"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
