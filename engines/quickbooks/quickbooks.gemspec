require_relative "lib/quickbooks/version"

Gem::Specification.new do |spec|
  spec.name = "quickbooks"
  spec.version = Quickbooks::VERSION
  spec.summary = "QuickBooks Online invoicing and recurring billing for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-quickbooks"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
