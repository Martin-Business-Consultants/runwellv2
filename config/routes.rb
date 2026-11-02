Rails.application.routes.draw do
  root "briefings#show"

  get "theme/:digest", to: "themes#show", as: :theme_stylesheet, constraints: { digest: /[0-9a-f]+/ }, format: false
  resource :session
  get "session/two_factor", to: "sessions/two_factors#new", as: :new_session_two_factor
  post "session/two_factor", to: "sessions/two_factors#create", as: :session_two_factor
  get "session/link", to: "sessions/links#new", as: :new_session_link
  post "session/link", to: "sessions/links#create", as: :session_link_request
  get "session/link/:token", to: "sessions/links#show", as: :staff_session_link
  post "session/link/:token", to: "sessions/links#update"
  resource :signup, only: %i[ new create ]
  scope "users", module: :users, as: :user do
    resources :invitations, only: %i[new create update destroy]
  end
  resources :users, only: %i[index show update] do
    scope module: :users do
      resource :avatar, only: :show
      resource :deactivation, only: %i[create destroy]
      resource :two_factor, only: :destroy
      resource :password, only: %i[create update]
      resource :sessions, only: :destroy
      resource :connections, only: :destroy
    end
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

  # Many records at once, from a table's selection (BulkAction).
  namespace :bulk do
    resource :todos, path: "work", only: %i[update destroy]
    resource :clients, only: %i[update destroy]
    resource :users, only: :update
    resource :engagements, only: :destroy do
      resource :closure, only: :create, module: :engagements
    end
  end
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

  resource :settings, only: :show
  # Settings > People became Users, in the left nav.
  get "settings/people", to: redirect("/users")
  get "settings/people/:id", to: redirect("/users/%{id}")

  namespace :settings do
    resource :setup, only: :show
    resource :address, only: %i[show update]
    resource :appearance, only: %i[show update]
    resource :theme_brief, only: :show
    resource :account, only: %i[show update]
    resource :menu, only: :update
    resource :two_factor, only: %i[new create destroy] do
      resource :recovery_codes, only: :create, module: :two_factors
    end
    resource :two_factor_requirement, only: :update
    resource :security, only: :show
    resource :roles, only: :show
    resource :passwordless, only: :update
    resource :names, only: %i[show update]
    resources :exports, only: %i[index create show]
    resource :audit_log, only: :show
    resources :webhooks, only: %i[index create update destroy]
    resource :views, only: %i[show update]
    resource :email, only: %i[show update] do
      resource :test_message, only: :create, module: :emails
      resource :inbound, only: :update, module: :emails
      resource :smtp, only: :update, module: :emails
    end
    resources :fields, only: %i[index create update destroy]
    namespace :plugins do
      resources :installations, only: :create
      resource :check, only: :create
    end
    resources :plugins, only: %i[index show update destroy], param: :key do
      resource :upgrade, only: :create, module: :plugins
    end
    resources :connected_apps, only: %i[index create destroy] do
      resource :pause, only: %i[create destroy], module: :connected_apps
    end
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

  resources :clients do
    resources :contacts, only: %i[new create edit update destroy], shallow: true
    resources :engagements, only: :create
    resources :todos, only: :create, path: "work"
  end

  resources :engagements, param: :ref do
    member do
      post :close
      post :reopen
    end
    resource :erasure, only: :create, module: :engagements
    resources :scope_items, only: %i[show create update destroy], shallow: true
    resources :todos, only: :create, path: "work"
  end

  # Work lives at /work (the models and helpers stay todo_*). The old /todos addresses redirect,
  # keeping the query string, so bookmarks and briefs copied before the move still open.
  namespace :todos, path: "work" do
    resources :columns, only: :show
  end
  resources :todos, path: "work", only: %i[index show create edit update destroy] do
    get :brief, on: :member
    resources :assignments, only: :create, module: :todos
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
  # Requests and commitments are work now: old addresses land on unassigned work.
  get "requests(/*rest)", to: redirect("/work?owner=none")
  get "commitments(/*rest)", to: redirect("/work")
  get "quick_actions/new", to: "quick_actions#new", as: :new_quick_action
  get "quick_actions/records", to: "quick_actions/records#index", as: :quick_action_records
  resources :notes, only: %i[create destroy]
  resources :documents, only: %i[create update destroy]

  namespace :portal do
    root "engagements#index"
    resource :session, only: %i[new create destroy]
    get "session/:token", to: "sessions#show", as: :session_link
    resources :engagements, param: :ref, only: %i[index show]
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
