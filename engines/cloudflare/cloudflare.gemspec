require_relative "lib/cloudflare/version"

Gem::Specification.new do |spec|
  spec.name = "cloudflare"
  spec.version = Cloudflare::VERSION
  spec.summary = "Runwell behind Cloudflare's proxy: real visitor addresses and https, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-cloudflare"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
