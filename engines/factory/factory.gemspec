Gem::Specification.new do |spec|
  spec.name = "factory"
  spec.version = "0.1.0"
  spec.summary = "Hands ready work to AI agents on runners, and tracks every run, as a Runwell plugin"
  spec.authors = [ "Runwell" ]
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
