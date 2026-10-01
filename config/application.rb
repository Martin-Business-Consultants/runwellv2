require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Plugins installed on this server (RUNWELL_DATA_DIR/plugins), before the app initializes so
# their engines take part like any other.
require_relative "installed_plugins"
InstalledPlugins.load!

module Runwellv2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Times are stored in UTC and shown in the agency's zone: Eastern unless TIME_ZONE names another
    # (a Rails name like "Pacific Time (US & Canada)" or an IANA one like "America/Chicago"). A client
    # with its own zone (Client#time_zone) sees its portal, approval pages and emails in that zone.
    config.time_zone = ENV.fetch("TIME_ZONE", "Eastern Time (US & Canada)")
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
