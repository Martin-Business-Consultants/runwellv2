# A bearer token acting as one person, with exactly that person's role: what the UI lets them
# do, an agent holding their token can do, and nothing more. The person is on staff (user), or a
# client's contact, whose token reaches only their portal (Portal::McpController). Personal
# tokens don't expire until revoked; OAuth tokens expire hourly and are refreshed. Only SHA-256
# digests are stored, so a token is shown once, when it's made. A paused token is refused until
# it's resumed; every call made with one is logged (AgentCall).
class AccessToken < ApplicationRecord
  KINDS = %w[personal oauth].freeze
  OAUTH_LIFETIME = 1.hour
  REFRESH_LIFETIME = 90.days

  belongs_to :user, optional: true
  belongs_to :contact, optional: true
  belongs_to :oauth_client, optional: true
  has_many :agent_calls, dependent: :delete_all
  has_many :agent_idempotency_keys, dependent: :delete_all

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validate { errors.add(:base, "A token belongs to a person on staff or a client's contact") unless user.present? ^ contact.present? }

  scope :live, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :ordered, -> { order(created_at: :desc) }

  attr_reader :plaintext, :refresh_plaintext

  class << self
    def digest(plaintext) = OpenSSL::Digest::SHA256.hexdigest(plaintext.to_s)

    def generate = "rw_#{SecureRandom.base58(40)}"

    # A new token; its plaintext is readable once, on the returned record.
    def issue!(name:, user: nil, contact: nil, kind: "personal", oauth_client: nil, read_only: false)
      plaintext = generate
      attrs = { user: user, contact: contact, name: name, kind: kind, oauth_client: oauth_client, token_digest: digest(plaintext), read_only: read_only }
      refresh = nil
      if kind == "oauth"
        refresh = generate
        attrs.merge!(expires_at: OAUTH_LIFETIME.from_now, refresh_token_digest: digest(refresh), refresh_expires_at: REFRESH_LIFETIME.from_now)
      end
      create!(attrs).tap { it.instance_variable_set(:@plaintext, plaintext); it.instance_variable_set(:@refresh_plaintext, refresh) }
    end

    # The live token for a bearer string, if its holder can still use it: an active person on
    # staff, or a contact who still has portal access. Each surface takes only its own kind.
    def authenticate(plaintext)
      return if plaintext.blank?

      token = live.includes(:user, :contact).find_by(token_digest: digest(plaintext))
      token if token&.holder_active?
    end

    def authenticate_staff(plaintext) = authenticate(plaintext)&.then { it if it.user }
    def authenticate_contact(plaintext) = authenticate(plaintext)&.then { it if it.contact }

    # OAuth refresh: the old token is revoked and a new pair issued.
    def refresh!(refresh_plaintext)
      old = where(revoked_at: nil).where("refresh_expires_at > ?", Time.current).find_by(refresh_token_digest: digest(refresh_plaintext))
      return unless old&.holder_active?

      transaction do
        old.revoke!
        issue!(user: old.user, contact: old.contact, name: old.name, kind: "oauth", oauth_client: old.oauth_client, read_only: old.read_only).tap do |fresh|
          fresh.update_column(:paused_at, old.paused_at) if old.paused_at
        end
      end
    end
  end

  def scope = [ (read_only? ? "runwell:read" : "runwell"), ("runwell:portal" if contact) ].compact.join(" ")

  def holder_active? = user ? user.active? : contact&.portal?
  def holder_name = user&.display_name || contact&.name
  def client? = contact.present?

  def pause! = update!(paused_at: Time.current)
  def resume! = update!(paused_at: nil)
  def paused? = paused_at.present?

  def revoke! = update!(revoked_at: Time.current)
  def revoked? = revoked_at.present?

  # Written at most once a minute: every agent call carries the token.
  def used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end
