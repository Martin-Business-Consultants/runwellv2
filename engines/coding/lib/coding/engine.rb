module Coding
  # A Runwell plugin: git repositories on clients, engagements and todos, so work can be
  # cloned and started from a terminal (checkout_work), with GitHub's pull requests, checks,
  # deploys, issues and repo access brought in once Settings > Code is connected. It owns its
  # tables and extends the core only through Runwell::Plugins, load hooks and events.
  class Engine < ::Rails::Engine

    initializer "coding.routes" do |app|
      app.routes.append do
        scope "code", module: "coding", as: "coding" do
          resource :settings, only: %i[show update destroy]
          resource :authorization, only: %i[create show]
          resource :sync, only: :create
          resource :people, only: :update
          resource :identity, only: :update
          resources :repositories, only: %i[create update destroy] do
            resource :hook, only: :create
            resource :deploy_sharing, only: %i[create destroy]
          end
          resources :todos, path: "work", only: [] do
            resource :checkout, only: :show
            resource :progress, only: :create, controller: "progress"
            resource :completion, only: :create
            resource :scope_flag, only: :create
          end
          resources :time_suggestions, only: %i[index create]
          resource :time_dismissal, only: :create
          post "github/webhooks", to: "webhooks#create", as: :github_webhooks
        end
      end
    end

    initializer "coding.helpers" do
      ActiveSupport.on_load(:action_view) { include Coding::CodeHelper }
    end

    initializer "coding.models" do
      ActiveSupport.on_load(:runwell_todo) do
        has_many :coding_repositories, class_name: "Coding::Repository", as: :linkable, dependent: :destroy
        has_many :coding_branches, class_name: "Coding::Branch", dependent: :destroy
        has_many :coding_commits, class_name: "Coding::Commit", dependent: :nullify
      end
      ActiveSupport.on_load(:runwell_engagement) { has_many :coding_repositories, class_name: "Coding::Repository", as: :linkable, dependent: :destroy }
      ActiveSupport.on_load(:runwell_client) { has_many :coding_repositories, class_name: "Coding::Repository", as: :linkable, dependent: :destroy }
      ActiveSupport.on_load(:runwell_user) { has_one :coding_identity, class_name: "Coding::Identity", dependent: :destroy }
    end

    config.to_prepare do
      Runwell::Plugins.agent_brief :coding, ->(todo, base_url) { Coding::Brief.call(todo, base_url) }
      Runwell::Plugins.register :coding, name: "Code", version: Coding::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.1.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-coding",
        description: "Link git repositories to clients, engagements and work so an agent can clone and start from a todo. With GitHub connected: pull requests and checks on work, deploys on the timeline, issues as requests, time suggested from commits, and repo access to review when someone leaves."
      Runwell::Plugins.settings :coding, "Code", -> { coding_settings_path }
      Runwell::Plugins.slot :client_panel, :coding, "coding/slots/client_panel"
      Runwell::Plugins.slot :engagement_panel, :coding, "coding/slots/engagement_panel"
      Runwell::Plugins.slot :todo_panel, :coding, "coding/slots/todo_panel"
      Runwell::Plugins.slot :portal_engagement_panel, :coding, "coding/slots/portal_engagement_panel"
      Runwell::Plugins.quick_action :coding, label: "Repository", title: "Link a repository", icon: "monitor", partial: "coding/quick_actions/repository",
        types: Coding::Repository::LINKABLE_TYPES, context: ->(record) { Coding::Repository.linkable_for(record) }
      Runwell::Plugins.nightly :coding, -> { Coding::SyncJob.perform_later }
      Runwell::Plugins.stylesheet :coding, "coding/code"
      Runwell::Plugins.briefing :coding, "Code needs attention", partial: "coding/briefing/item", items: ->(_user) { Coding::Attention.items }
    end
  end
end
