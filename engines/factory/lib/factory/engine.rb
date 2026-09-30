module Factory
  # A Runwell plugin: hands ready work to AI agents running unattended on runners (the
  # runwell-runner program, in engines/factory/runner), and tracks every run. A person queues work, or an
  # approval does; a runner claims the next piece with a lease, keeps it alive with heartbeats,
  # and finishes with a summary, branch, pull request and cost. Finished work goes to review;
  # a person still checks and merges it. Owns its tables and reaches the core only through
  # Runwell::Plugins, load hooks and events. Works with the Code plugin, which says where the
  # code is.
  class Engine < ::Rails::Engine
    initializer "factory.migrations" do |app|
      config.paths["db/migrate"].expanded.each { |path| app.config.paths["db/migrate"] << path }
    end

    initializer "factory.routes" do |app|
      app.routes.append do
        scope "factory", module: "factory", as: "factory" do
          get "/", to: "dashboards#show", as: :root
          resource :settings, only: %i[show update]
          resource :claim, only: :create
          resources :todos, path: "work", only: [] do
            resource :item, only: %i[create destroy]
          end
          resources :engagements, param: :ref, only: [] do
            resource :queue, only: :create
          end
          resources :runs, only: :show do
            resource :heartbeat, only: :create
            resource :finish, only: :create
            resource :cancellation, only: :create
          end
        end
      end
    end

    initializer "factory.helpers" do
      ActiveSupport.on_load(:action_view) { include Factory::FactoryHelper }
    end

    initializer "factory.events" do
      ActiveSupport::Notifications.subscribe("event.runwell") { |*, payload| Factory::Events.handle(payload[:event]) }
    end

    initializer "factory.models" do
      ActiveSupport.on_load(:runwell_todo) do
        has_one :factory_item, class_name: "Factory::Item", dependent: :destroy
        has_many :factory_runs, class_name: "Factory::Run", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :factory, name: "Factory", version: "0.1.0", author: "Runwell",
        bundled: true, enabled_by_default: false,
        description: "Hand ready work to AI agents that run unattended on your own machines or servers (the runwell-runner program). Runners claim the next piece, open a pull request and put it in review for a person. Limits on runs at once, time, attempts and a monthly budget. Needs the Code plugin for repositories."
      Runwell::Plugins.nav :factory, "Factory", -> { factory_root_path }
      Runwell::Plugins.settings :factory, "Factory", -> { factory_settings_path }
      Runwell::Plugins.permission :factory, :queue_agent_work, name: "Hand work to agents and cancel runs", roles: %w[owner manager]
      Runwell::Plugins.permission :factory, :run_agent_work, name: "Run a factory runner (claim and report work)", roles: %w[owner manager]
      Runwell::Plugins.slot :todo_panel, :factory, "factory/slots/todo_panel"
      Runwell::Plugins.slot :engagement_panel, :factory, "factory/slots/engagement_panel"
      Runwell::Plugins.slot :portal_engagement_panel, :factory, "factory/slots/portal_engagement_panel"
      Runwell::Plugins.briefing :factory, "Factory needs you", partial: "factory/briefing/item", items: ->(_user) { Factory::Attention.items }
      Runwell::Plugins.stylesheet :factory, "factory/factory"
    end
  end
end
