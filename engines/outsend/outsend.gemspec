require_relative "lib/outsend/version"

Gem::Specification.new do |spec|
  spec.name = "outsend"
  spec.version = Outsend::VERSION
  spec.summary = "Send Runwell's email through Outsend, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-outsend"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
