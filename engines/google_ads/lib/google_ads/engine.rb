module GoogleAds
  # A Runwell plugin: read-only Google Ads reporting. It connects to the agency's Google Ads
  # manager account, links an ad account to an engagement, copies spend and results nightly,
  # and shows the report to staff and in the client portal. It never changes an ad account.
  # It owns its tables and extends the core only through Runwell::Plugins and load hooks.
  class Engine < ::Rails::Engine

    initializer "google_ads.routes" do |app|
      app.routes.append do
        scope "google-ads", module: "google_ads", as: "google_ads" do
          resource :settings, only: %i[show update destroy]
          resource :authorization, only: %i[create show]
          resource :sync, only: :create
          resources :engagements, param: :ref, only: [] do
            resource :link, only: %i[create destroy]
            resource :report, only: :show
          end
        end
        scope "portal/advertising", module: "google_ads/portal", as: "google_ads_portal" do
          resource :report, only: :show, path: ""
        end
      end
    end

    initializer "google_ads.helpers" do
      ActiveSupport.on_load(:action_view) { include GoogleAds::ReportsHelper }
    end

    initializer "google_ads.models" do
      ActiveSupport.on_load(:runwell_engagement) { has_one :google_ads_link, class_name: "GoogleAds::Link", dependent: :destroy }
    end

    config.to_prepare do
      Runwell::Plugins.register :google_ads, name: "Google Ads", version: GoogleAds::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.1.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-google-ads",
        description: "Read-only Google Ads reporting: link an ad account to an engagement, copy its spend and results nightly, and show clients a monthly report in their portal. Alerts when an account stops serving."
      Runwell::Plugins.settings :google_ads, "Google Ads", -> { google_ads_settings_path }
      Runwell::Plugins.permission :google_ads, :link_ad_accounts, name: "Link Google Ads accounts to engagements", roles: %w[owner manager]
      Runwell::Plugins.slot :engagement_panel, :google_ads, "google_ads/slots/engagement_panel"
      Runwell::Plugins.slot :portal_home, :google_ads, "google_ads/slots/portal_home"
      Runwell::Plugins.slot :portal_engagement_panel, :google_ads, "google_ads/slots/portal_engagement_panel"
      Runwell::Plugins.portal_nav :google_ads, "Advertising",
        -> { google_ads_portal_report_path if GoogleAds::Link.for_client(current_contact.client).exists? }
      Runwell::Plugins.nightly :google_ads, -> { GoogleAds::SyncJob.perform_later }
      Runwell::Plugins.stylesheet :google_ads, "google_ads/charts"
      Runwell::Plugins.briefing :google_ads, "Ads stopped", partial: "google_ads/briefing/account",
        items: ->(_user) { GoogleAds::Account.blocked.where(customer_id: GoogleAds::Link.select(:customer_id)).order(:status_changed_at) }
    end
  end
end
