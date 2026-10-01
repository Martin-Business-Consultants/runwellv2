require_relative "lib/reporting/version"

Gem::Specification.new do |spec|
  spec.name = "reporting"
  spec.version = Reporting::VERSION
  spec.summary = "Financial reporting for Runwell, read from the QuickBooks plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-reporting"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
