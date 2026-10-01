require_relative "lib/account_management/version"

Gem::Specification.new do |spec|
  spec.name = "account_management"
  spec.version = AccountManagement::VERSION
  spec.summary = "Account management for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-account-management"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
