Gem::Specification.new do |spec|
  spec.name = "google_ads"
  spec.version = "0.1.0"
  spec.summary = "Google Ads reporting for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
