# A way to sign in other than a password: Google, Microsoft (Entra ID) or GitHub, through
# OmniAuth. The owner registers an app with the provider and saves its keys here (Settings >
# Sign-in); config/initializers/omniauth.rb reads them on each request, so no restart. People
# connect their own accounts in Settings > Your account (Identity). Nobody joins this way: an
# account still starts with an invitation.
class SignInProvider < ApplicationRecord
  PROVIDERS = {
    "google_oauth2" => { name: "Google", icon: "globe", console: "https://console.cloud.google.com/apis/credentials" },
    "entra_id" => { name: "Microsoft", icon: "monitor", console: "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade" },
    "github" => { name: "GitHub", icon: "share", console: "https://github.com/settings/applications/new" }
  }.freeze

  encrypts :client_secret

  validates :key, inclusion: { in: PROVIDERS.keys }, uniqueness: true
  validates :client_id, :client_secret, presence: true, if: :enabled?

  scope :usable, -> { where(enabled: true).where.not(client_id: [ nil, "" ]).where.not(client_secret: nil) }

  def self.for(key) = find_or_initialize_by(key: key.to_s)
  def self.usable_keys = usable.pluck(:key).sort_by { PROVIDERS.keys.index(it) }

  def self.name_for(key) = PROVIDERS.dig(key.to_s, :name) || key.to_s.titleize

  # OmniAuth's setup phase: hand the strategy this install's keys, or stop if the owner hasn't
  # switched the provider on.
  def self.configure(strategy, key)
    provider = usable.find_by(key: key)
    raise ActionController::RoutingError, "#{name_for(key)} sign-in isn't set up" unless provider

    strategy.options.client_id = provider.client_id
    strategy.options.client_secret = provider.client_secret
    strategy.options.tenant_id = provider.tenant_id.presence || "common" if key == "entra_id"
  end

  def name = self.class.name_for(key)
  def usable? = enabled? && client_id.present? && client_secret.present?
end
