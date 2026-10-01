module Qa
  # A Runwell plugin: quality assurance for what an agency puts in front of its clients'
  # customers. Each client's checks hold the source of truth (From addresses, recipients,
  # webhook URLs, phone numbers, prices, promo lines and when they end) and the proof each was
  # tested: by a person, an agent, a nightly page fetch, or the site's own report to its check's
  # URL. Failures become issues that have to say where, how, expected and actual; a fix names
  # its root cause and is verified by someone else or the next passing test. Work can be gated
  # on a check, so it can't be marked done until the check passes again. Owns its tables and
  # reaches the core only through Runwell::Plugins, load hooks and events.
  class Engine < ::Rails::Engine

    initializer "qa.routes" do |app|
      app.routes.append do
        scope "qa", module: "qa", as: "qa" do
          get "/", to: "dashboards#show", as: :root
          resources :checks, only: %i[new create show edit update destroy] do
            resources :expectations, only: %i[create edit update destroy]
            resources :runs, only: :create
            resource :fetch, only: :create
            resource :token, only: :create
          end
          resources :runs, only: :show
          resources :issues, only: %i[index show create edit update destroy] do
            member do
              post :fix
              post :verify
              post :reopen
            end
          end
          resources :todos, path: "work", only: [] do
            resources :gates, only: %i[create destroy]
          end
          post "report/:token", to: "reports#create", as: :report
        end
      end
    end

    initializer "qa.helpers" do
      ActiveSupport.on_load(:action_view) { include Qa::QaHelper }
    end

    initializer "qa.events" do
      ActiveSupport::Notifications.subscribe("event.runwell") { |*, payload| Qa::Events.handle(payload[:event]) }
    end

    initializer "qa.models" do
      # Issues first: they point at the checks' runs.
      ActiveSupport.on_load(:runwell_client) do
        has_many :qa_issues, class_name: "Qa::Issue", dependent: :destroy
        has_many :qa_checks, class_name: "Qa::Check", dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_engagement) do
        has_many :qa_checks, class_name: "Qa::Check", dependent: :nullify
        has_many :qa_issues, class_name: "Qa::Issue", dependent: :nullify
      end
      ActiveSupport.on_load(:runwell_todo) do
        has_many :qa_gates, class_name: "Qa::Gate", dependent: :destroy
        has_many :qa_issues, class_name: "Qa::Issue", dependent: :nullify

        # The gate: work with QA checks on it isn't done until they pass again.
        validate(if: -> { will_save_change_to_status?(to: "done") && Runwell::Plugins.enabled?(:qa) }) do
          Qa::Gate.problems_for(self).each { errors.add(:base, "QA first: #{it}") }
        end
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :qa, name: "QA", version: Qa::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.1.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-qa",
        description: "Keep each client’s source of truth (email senders and recipients, webhooks, phone numbers, prices, promos and when they end) and prove it’s right: tests by people and agents, nightly page checks, and the site’s own reports. Failures become issues with root causes, work can’t be marked done until its checks pass, and home shows what’s failing, expiring or overdue."
      Runwell::Plugins.nav :qa, "QA", -> { qa_root_path }
      Runwell::Plugins.permission :qa, :manage_qa, name: "Set QA checks and their source of truth", roles: %w[owner manager]
      Runwell::Plugins.slot :client_panel, :qa, "qa/slots/client_panel"
      Runwell::Plugins.slot :engagement_panel, :qa, "qa/slots/engagement_panel"
      Runwell::Plugins.slot :todo_panel, :qa, "qa/slots/todo_panel"
      Runwell::Plugins.quick_action :qa, label: "QA issue", title: "Log a QA issue", icon: "check-circle", partial: "qa/quick_actions/issue",
        types: Qa::Issue::RECORD_TYPES, context: ->(record) { Qa::Issue::RECORD_TYPES.include?(record.class.name) ? record : record.try(:engagement) || record.try(:client) }
      Runwell::Plugins.briefing :qa, "QA needs you", partial: "qa/briefing/item", items: ->(user) { Qa::Attention.items(user) }
      Runwell::Plugins.nightly :qa, -> { Qa::NightlyJob.perform_later }
      Runwell::Plugins.agent_brief :qa, ->(todo, base_url) { Qa::Brief.call(todo, base_url) }
      Runwell::Plugins.stylesheet :qa, "qa/qa"
    end
  end
end
