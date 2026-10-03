# A way to sign in other than a password: Google, Microsoft (Entra ID) or GitHub, through
# OmniAuth. The owner registers an app with the provider and saves its keys here (Settings >
# Sign-in); config/initializers/omniauth.rb reads them on each request, so no restart. People
# connect their own accounts in Settings > Your account (Identity). Nobody joins this way: an
# account still starts with an invitation.
class SignInProvider < ApplicationRecord
  PROVIDERS = {
    "google_oauth2" => { name: "Google", icon: "globe", console: "https://console.cloud.google.com/apis/credentials" },
    "entra_id" => { name: "Microsoft", icon: "monitor", console: "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade" },
    "github" => { name: "GitHub", icon: "share", console: "https://github.com/settings/applications/new" },
    "openid_connect" => { name: "Single sign-on", icon: "lock", console: nil }
  }.freeze

  encrypts :client_secret

  validates :key, inclusion: { in: PROVIDERS.keys }, uniqueness: true
  validates :client_id, :client_secret, presence: true, if: :enabled?
  validates :issuer, presence: true, format: { with: %r{\Ahttps://}, message: "should be the provider's https:// address" }, if: -> { enabled? && key == "openid_connect" }

  scope :usable, -> { where(enabled: true).where.not(client_id: [ nil, "" ]).where.not(client_secret: nil) }

  def self.for(key) = find_or_initialize_by(key: key.to_s)
  def self.usable_keys = usable.pluck(:key).sort_by { PROVIDERS.keys.index(it) }

  # Single sign-on goes by the name the owner gave it (Okta, Acme SSO); the others by their own.
  def self.name_for(key)
    return find_by(key: "openid_connect")&.label.presence || PROVIDERS.dig("openid_connect", :name) if key.to_s == "openid_connect"

    PROVIDERS.dig(key.to_s, :name) || key.to_s.titleize
  end

  # OmniAuth's setup phase: hand the strategy this install's keys, or stop if the owner hasn't
  # switched the provider on.
  def self.configure(strategy, key)
    provider = usable.find_by(key: key)
    raise ActionController::RoutingError, "#{name_for(key)} sign-in isn't set up" unless provider

    strategy.options.client_id = provider.client_id
    strategy.options.client_secret = provider.client_secret
    strategy.options.tenant_id = provider.tenant_id.presence || "common" if key == "entra_id"
    configure_openid_connect(strategy, provider) if key == "openid_connect"
  end

  # Any OpenID Connect provider (Okta, Auth0, Keycloak, JumpCloud, Google Workspace…), found
  # from its issuer's discovery document.
  def self.configure_openid_connect(strategy, provider)
    strategy.options.issuer = provider.issuer
    strategy.options.discovery = true
    strategy.options.pkce = true
    strategy.options.scope = %i[openid email profile]
    strategy.options.client_options.identifier = provider.client_id
    strategy.options.client_options.secret = provider.client_secret
    strategy.options.client_options.redirect_uri = "#{OmniAuth.config.full_host.call(strategy.env)}/auth/openid_connect/callback"
  end

  def name = key == "openid_connect" ? (label.presence || PROVIDERS.dig(key, :name)) : self.class.name_for(key)
  def usable? = enabled? && client_id.present? && client_secret.present?
end
