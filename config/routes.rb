Rails.application.routes.draw do
  root "briefings#show"

  resource :session
  resource :signup, only: %i[ new create ]
  resources :users, only: [] do
    resource :avatar, only: :show, module: :users
  end
  get "signup", to: redirect("/signup/new")
  resources :invitations, only: %i[show update], param: :token
  resources :passwords, param: :token

  resource :briefing, only: :show
  resource :me, only: :show, controller: :me

  # Agents: the MCP server, and OAuth for connectors (see Agent::, Oauth::)
  post "mcp", to: "mcp#create", as: :mcp
  get "resolve", to: "resolutions#show", as: :resolution
  get "changes", to: "changes#index", as: :changes
  get "install/cli", to: "cli#install", as: :cli_install
  get "install/runwell", to: "cli#show", as: :cli_script
  get ".well-known/oauth-protected-resource(/*resource)", to: "oauth/metadata#protected_resource", as: :oauth_protected_resource
  get ".well-known/oauth-authorization-server(/*issuer)", to: "oauth/metadata#authorization_server", as: :oauth_authorization_server
  namespace :oauth do
    resources :clients, only: :create
    resource :authorization, only: %i[show create]
    resource :token, only: :create
    resource :revocation, only: :create
  end
  resource :search, only: :show
  get "help", to: redirect("/settings/help")
  resource :setup, only: :destroy

  resource :settings, only: :show
  namespace :settings do
    resource :address, only: %i[show update]
    resource :appearance, only: %i[show update]
    resource :help, only: :show
    get "help/mcp", to: "helps#mcp", as: :help_mcp
    get "help/ai", to: "helps#ai", as: :help_ai
    resource :names, only: %i[show update]
    resource :views, only: %i[show update]
    resource :email, only: %i[show update] do
      resource :test_message, only: :create, module: :emails
    end
    resources :fields, only: %i[index create update destroy]
    namespace :plugins do
      resources :installations, only: :create
      resource :check, only: :create
    end
    resources :plugins, only: %i[index show update destroy], param: :key do
      resource :upgrade, only: :create, module: :plugins
    end
    resources :people, only: %i[index update] do
      resource :deactivation, only: %i[create destroy], module: :people
    end
    resources :invitations, only: %i[create update destroy]
    resources :connected_apps, only: %i[index create destroy] do
      resource :pause, only: %i[create destroy], module: :connected_apps
    end
    resource :client_agent_approvals, only: :update
    resource :updates, only: %i[show create] do
      resource :check, only: :create, module: :updates
      resource :failures, only: :destroy, module: :updates
    end
  end

  namespace :prompts do
    resources :users, only: :index
  end

  namespace :notifications do
    resource :tray, only: :show
  end
  resources :notifications, only: %i[index show] do
    scope module: :notifications do
      resource :reading, only: %i[create destroy]
      collection do
        resource :bulk_reading, only: :create
      end
    end
  end
  resources :questions, only: [] do
    member do
      post :answer
      post :dismiss
    end
  end

  resources :clients do
    resources :contacts, only: %i[new create edit update destroy], shallow: true
    resources :commitments, only: :create
    resources :engagements, only: :create
  end

  resources :engagements, param: :ref do
    member { post :close }
    resources :agreement_versions, only: %i[create update destroy], shallow: true do
      member do
        post :send_out
        post :record_decision
        post :issue_link
      end
      resources :scope_items, only: %i[show create update destroy], shallow: true
    end
    resources :todos, only: :create, path: "work"
    resources :commitments, only: :create
  end

  # Work lives at /work (the models and helpers stay todo_*). The old /todos addresses redirect,
  # keeping the query string, so bookmarks and briefs copied before the move still open.
  namespace :todos, path: "work" do
    resources :columns, only: :show
  end
  resources :todos, path: "work", only: %i[index show edit update destroy] do
    get :brief, on: :member
  end
  get "todos(/*rest)", format: false, to: redirect { |params, request|
    [ "/work", params[:rest] ].compact.join("/") + (request.query_string.present? ? "?#{request.query_string}" : "")
  }

  namespace :columns do
    resources :todos, path: "work", only: [] do
      scope module: :todos do
        namespace :drops do
          resource :stream, only: :create
          resource :column, only: :create
          resource :closure, only: :create
        end
      end
    end
  end
  resources :commitments, only: %i[index edit update destroy] do
    member { post :resolve }
  end
  resources :requests do
    member do
      post :promote_engagement
      post :promote_change
      post :promote_todo
      post :promote_commitment
      post :dismiss
    end
  end
  get "quick_actions/new", to: "quick_actions#new", as: :new_quick_action
  resources :notes, only: %i[create destroy]
  resources :documents, only: %i[create update destroy]

  # Client approval, from the emailed link. Approval only on POST.
  get "approve/:token", to: "approvals#show", as: :approval
  post "approve/:token", to: "approvals#create"

  namespace :portal do
    root "engagements#index"
    resource :session, only: %i[new create destroy]
    get "session/:token", to: "sessions#show", as: :session_link
    resources :engagements, param: :ref, only: %i[index show] do
      resources :approvals, only: :create
    end
    resources :todos, path: "work", only: :index
    get "todos", to: redirect("/portal/work")
    resources :requests, only: %i[index new create]
    resource :me, only: :show
    post "mcp", to: "mcp#create", as: :mcp
    resources :connected_apps, only: %i[index create destroy]
    resource :oauth_authorization, path: "oauth/authorization", only: %i[show create]
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  get "up" => "rails/health#show", as: :rails_health_check
end
