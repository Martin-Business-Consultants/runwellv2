require_relative "lib/google_ads/version"

Gem::Specification.new do |spec|
  spec.name = "google_ads"
  spec.version = GoogleAds::VERSION
  spec.summary = "Google Ads reporting for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-google-ads"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
