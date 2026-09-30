Gem::Specification.new do |spec|
  spec.name = "cloudflare"
  spec.version = "0.1.0"
  spec.summary = "Runwell behind Cloudflare's proxy: real visitor addresses and https, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
