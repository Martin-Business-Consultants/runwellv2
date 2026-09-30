# A bearer token acting as one person, with exactly that person's role: what the UI lets them
# do, an agent holding their token can do, and nothing more. Personal tokens don't expire until
# revoked; OAuth tokens expire hourly and are refreshed. Only SHA-256 digests are stored, so a
# token is shown once, when it's made.
class AccessToken < ApplicationRecord
  KINDS = %w[personal oauth].freeze
  OAUTH_LIFETIME = 1.hour
  REFRESH_LIFETIME = 90.days

  belongs_to :user
  belongs_to :oauth_client, optional: true

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :live, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :ordered, -> { order(created_at: :desc) }

  attr_reader :plaintext, :refresh_plaintext

  class << self
    def digest(plaintext) = OpenSSL::Digest::SHA256.hexdigest(plaintext.to_s)

    def generate = "rw_#{SecureRandom.base58(40)}"

    # A new token; its plaintext is readable once, on the returned record.
    def issue!(user:, name:, kind: "personal", oauth_client: nil, read_only: false)
      plaintext = generate
      attrs = { user: user, name: name, kind: kind, oauth_client: oauth_client, token_digest: digest(plaintext), read_only: read_only }
      refresh = nil
      if kind == "oauth"
        refresh = generate
        attrs.merge!(expires_at: OAUTH_LIFETIME.from_now, refresh_token_digest: digest(refresh), refresh_expires_at: REFRESH_LIFETIME.from_now)
      end
      create!(attrs).tap { it.instance_variable_set(:@plaintext, plaintext); it.instance_variable_set(:@refresh_plaintext, refresh) }
    end

    # The live token for a bearer string, if its person is still active.
    def authenticate(plaintext)
      return if plaintext.blank?

      token = live.includes(:user).find_by(token_digest: digest(plaintext))
      token if token&.user&.active?
    end

    # OAuth refresh: the old token is revoked and a new pair issued.
    def refresh!(refresh_plaintext)
      old = where(revoked_at: nil).where("refresh_expires_at > ?", Time.current).find_by(refresh_token_digest: digest(refresh_plaintext))
      return unless old&.user&.active?

      transaction do
        old.revoke!
        issue!(user: old.user, name: old.name, kind: "oauth", oauth_client: old.oauth_client, read_only: old.read_only)
      end
    end
  end

  def scope = read_only? ? "runwell:read" : "runwell"

  def revoke! = update!(revoked_at: Time.current)
  def revoked? = revoked_at.present?

  # Written at most once a minute: every agent call carries the token.
  def used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end
