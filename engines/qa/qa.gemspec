require_relative "lib/qa/version"

Gem::Specification.new do |spec|
  spec.name = "qa"
  spec.version = Qa::VERSION
  spec.summary = "Quality assurance for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-qa"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib,examples}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
