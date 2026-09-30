# Rebuild the agent tool catalogue when code reloads in development.
Rails.application.reloader.to_prepare { Agent::Catalogue.reset! }
