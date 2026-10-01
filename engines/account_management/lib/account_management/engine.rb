module AccountManagement
  # A Runwell plugin: the working system of whoever runs client relationships. Each client has a
  # lead. Every client meeting has an agenda sent ahead and a recap sent after, both timestamped,
  # and its action items become core commitments with owners and dates. The access register
  # records who owns each outside account (a Facebook page, an ad account, a pixel, a domain),
  # what access we hold and when its token expires. Leads send a written weekly update, and a
  # scorecard measures each lead against the playbook's targets from what they actually did.
  # Owns its tables and reaches the core only through Runwell::Plugins and load hooks.
  class Engine < ::Rails::Engine

    initializer "account_management.routes" do |app|
      app.routes.append do
        scope "accounts", module: "account_management", as: "account_management" do
          get "/", to: "dashboards#show", as: :root
          resource :playbook, only: :show
          resources :scorecards, only: :show
          resources :meetings do
            member do
              post :send_agenda
              post :send_recap
              post :cancel
            end
            resources :action_items, only: :create
          end
          resources :accesses, except: :show do
            post :verify, on: :member
          end
          resources :clients, only: [] do
            resource :lead, only: :update
          end
          resources :weekly_updates, path: "updates", except: :destroy do
            post :submit, on: :member
          end
        end
      end
    end

    initializer "account_management.helpers" do
      ActiveSupport.on_load(:action_view) { include AccountManagement::AccountsHelper }
    end

    initializer "account_management.models" do
      ActiveSupport.on_load(:runwell_client) do
        has_one :account_lead, class_name: "AccountManagement::Lead", dependent: :destroy
        has_many :account_meetings, class_name: "AccountManagement::Meeting", dependent: :destroy
        has_many :account_accesses, class_name: "AccountManagement::Access", dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_engagement) do
        has_many :account_meetings, class_name: "AccountManagement::Meeting", dependent: :nullify
      end
      ActiveSupport.on_load(:runwell_user) do
        has_many :account_leads, class_name: "AccountManagement::Lead", dependent: :destroy
        has_many :account_meetings, class_name: "AccountManagement::Meeting", foreign_key: :owner_id, dependent: :nullify
        has_many :weekly_updates, class_name: "AccountManagement::WeeklyUpdate", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :account_management, name: "Account management", version: AccountManagement::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.1.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-account-management",
        description: "A lead for every client. Client meetings with an agenda sent a day ahead and a recap within a day after, their action items kept as commitments. A register of each client’s outside accounts (pages, ad accounts, pixels, domains): who owns them, our access, where the login lives and when tokens expire. A written weekly update, and a scorecard that measures each lead against the playbook from what they actually did."
      Runwell::Plugins.nav :account_management, "Accounts", -> { account_management_root_path }
      Runwell::Plugins.permission :account_management, :manage_accounts, name: "Assign account leads and keep the access register", roles: %w[owner manager]
      Runwell::Plugins.permission :account_management, :view_scorecards, name: "See everyone’s account scorecard and weekly updates", roles: %w[owner manager]
      Runwell::Plugins.slot :client_panel, :account_management, "account_management/slots/client_panel"
      Runwell::Plugins.slot :engagement_panel, :account_management, "account_management/slots/engagement_panel"
      Runwell::Plugins.quick_action :account_management, label: "Meeting", title: "Plan a client meeting", icon: "comment",
        partial: "account_management/quick_actions/meeting", types: AccountManagement::Meeting::RECORD_TYPES,
        context: ->(record) { AccountManagement::Meeting::RECORD_TYPES.include?(record.class.name) ? record : record.try(:engagement) || record.try(:client) }
      Runwell::Plugins.briefing :account_management, "Accounts need you", partial: "account_management/briefing/item",
        items: ->(user) { AccountManagement::Attention.items(user) }
      Runwell::Plugins.stylesheet :account_management, "account_management/accounts"
    end
  end
end
