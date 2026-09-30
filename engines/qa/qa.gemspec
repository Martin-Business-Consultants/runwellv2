Gem::Specification.new do |spec|
  spec.name = "qa"
  spec.version = "0.1.0"
  spec.summary = "Quality assurance for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.files = Dir["{app,config,db,lib,examples}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
