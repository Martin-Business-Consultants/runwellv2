require_relative "lib/coding/version"

Gem::Specification.new do |spec|
  spec.name = "coding"
  spec.version = Coding::VERSION
  spec.summary = "Git repositories and GitHub for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-coding"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
