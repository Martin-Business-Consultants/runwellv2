module Outsend
  # A Runwell plugin: outbound mail through Outsend (getoutsend.com). Paste the API key in
  # Settings > Outsend and every email the app sends goes out through Outsend's SMTP; the
  # core's own SMTP settings, if any, only apply while the plugin is off. A Mail interceptor
  # decides per message, so switching the plugin on or off needs no restart. It owns one table.
  class Engine < ::Rails::Engine
    initializer "outsend.migrations" do |app|
      config.paths["db/migrate"].expanded.each { |path| app.config.paths["db/migrate"] << path }
    end

    initializer "outsend.routes" do |app|
      app.routes.append do
        scope "outsend", module: "outsend", as: "outsend" do
          resource :settings, only: %i[show update destroy]
          resource :test_message, only: :create
        end
      end
    end

    initializer "outsend.mail" do
      ActiveSupport.on_load(:action_mailer) do
        register_interceptor Outsend::Delivery
        register_observer Outsend::Delivery
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :outsend, name: "Outsend", version: "0.1.0", author: "Runwell",
        bundled: true, enabled_by_default: false, requires: ">= 2.0",
        description: "Send Runwell’s email through Outsend: paste your API key and every message goes out through Outsend’s SMTP, with no mail server settings to manage."
      Runwell::Plugins.settings :outsend, "Outsend", -> { outsend_settings_path }
    end
  end
end
