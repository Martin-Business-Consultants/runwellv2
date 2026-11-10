# Another Runwell install a person also works in, on the workspace rail at the far left of the nav
# (layouts/shared/_workspace_rail), with its unread notifications and what's waiting in its Intake.
#
# Linking goes both ways in one pass. On this install (A) someone adds B's address: A keeps a
# pending link with a one-time nonce (start!) and sends them to B's confirm page
# (Workspaces::LinksController). Confirming there (accept!, on B) has B's server post to A's
# handshake (Workspaces::HandshakesController, complete! on A) with the nonce and a key B made for A;
# A answers with a key of its own for B. Each install now holds the other's key (remote_key,
# encrypted) and the digest of the key it gave (key_digest). Keys never pass through the browser.
#
# A key reads one thing: the person's two counts, the install's name, icon and colour
# (Workspaces::BadgesController). It isn't a sign-in and reaches nothing else; each install keeps its
# own sessions. Unlinking on either side tells the other, which drops its half.
class WorkspaceLink < ApplicationRecord
  class Refused < StandardError; end

  NONCE_TTL = 15.minutes
  BADGE_TTL = 1.minute
  TIMEOUT = 4
  LOCAL_HOSTS = /\A(localhost|127\.0\.0\.1|\[::1\]|.+\.localhost|.+\.test)\z/

  belongs_to :user
  encrypts :remote_key

  scope :linked, -> { where.not(linked_at: nil) }
  scope :pending, -> { where(linked_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  validates :url, presence: true, uniqueness: { scope: :user_id, message: "is already on your rail" }

  before_create { self.position = (user.workspace_links.maximum(:position) || 0) + 1 }

  class << self
    # "crm.brem.io", "https://crm.brem.io/tasks" → "https://crm.brem.io". https only, but for a
    # local address in development.
    def origin(text)
      text = text.to_s.strip
      text = "https://#{text}" unless text.match?(%r{\Ahttps?://}i)
      uri = URI.parse(text)
      raise Refused, "That isn’t a web address" if uri.host.blank?

      local = uri.host.match?(LOCAL_HOSTS)
      raise Refused, "Runwell links only over https" unless uri.scheme == "https" || local

      port = uri.port == uri.default_port ? "" : ":#{uri.port}"
      "#{uri.scheme}://#{uri.host.downcase}#{port}"
    rescue URI::InvalidURIError
      raise Refused, "That isn’t a web address"
    end

    def digest(secret) = Digest::SHA256.hexdigest(secret.to_s)
    def new_secret = SecureRandom.base58(40)

    # The link a key was given for, while its person can still use this install.
    def for_key(key)
      return if key.blank?

      link = linked.includes(:user).find_by(key_digest: digest(key))
      link if link&.user&.active?
    end

    # On A: someone adds B. Returns the link and the nonce B's confirm page carries back.
    def start!(user:, url:, here:)
      url = origin(url)
      raise Refused, "That’s this workspace" if url == origin(here)

      link = user.workspace_links.find_or_initialize_by(url: url)
      raise Refused, "#{link.name || url} is already on your rail" if link.linked?

      nonce = new_secret
      link.update!(nonce_digest: digest(nonce), nonce_expires_at: NONCE_TTL.from_now)
      [ link, nonce ]
    end

    # On A: B's server, for someone who confirmed there, completes A's pending link and gets A's key.
    def complete!(nonce:, url:, key:, identity: {})
      link = pending.where(nonce_digest: digest(nonce)).where("nonce_expires_at > ?", Time.current).first if nonce.present?
      raise Refused, "That link has expired: add the workspace again" unless link && key.present? && link.url == origin(url)

      ours = new_secret
      link.update!(remote_key: key, key_digest: digest(ours), nonce_digest: nil, nonce_expires_at: nil, linked_at: Time.current, **identity_attributes(identity))
      ours
    end

    # On B: the person confirms the link A asked for. B makes a key for A, hands it over through
    # A's handshake, and keeps A's key in return.
    def accept!(user:, from:, nonce:, here:)
      url = origin(from)
      ours = new_secret
      answer = request(:post, "#{url}/workspace/handshake", body: { nonce: nonce, url: origin(here), key: ours, **identity(here) })
      raise Refused, answer&.dig("error") || "#{url} didn’t answer: is it a Runwell install, on 5.40 or later?" unless answer&.dig("key")

      link = user.workspace_links.find_or_initialize_by(url: url)
      link.update!(remote_key: answer["key"], key_digest: digest(ours), nonce_digest: nil, nonce_expires_at: nil, linked_at: Time.current, **identity_attributes(answer))
      link
    end

    # What this install says about itself to the others: its name, icon and colour.
    def identity(here)
      setting = Setting.current
      icon = setting.favicon.attached? ? Rails.application.routes.url_helpers.rails_blob_path(setting.favicon, disposition: :inline, only_path: true) : "/icon.png"
      { name: setting.mail_from_name.presence || URI.parse(here).host, icon_url: "#{here}#{icon}", color: setting.brand_color }
    end

    def identity_attributes(data)
      data = data.to_h.stringify_keys
      icon = data["icon_url"].to_s
      { name: data["name"].to_s.truncate(60).presence, color: data["color"].to_s[/\A#\h{3,8}\z/],
        icon_url: (icon if icon.match?(%r{\Ahttps?://})) }.compact
    end

    # JSON to or from another install; nil when it doesn't answer in time or answers otherwise.
    def request(method, url, body: nil, key: nil)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = TIMEOUT
      request = (method == :post ? Net::HTTP::Post : method == :delete ? Net::HTTP::Delete : Net::HTTP::Get).new(uri)
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{key}" if key
      if body
        request["Content-Type"] = "application/json"
        request.body = body.to_json
      end
      response = http.request(request)
      JSON.parse(response.body) if response.body.present? && response["Content-Type"].to_s.include?("json")
    rescue StandardError => error
      Rails.logger.info("[workspace] #{url}: #{error.class}: #{error.message}")
      nil
    end
  end

  def linked? = linked_at.present?
  def label = name.presence || URI.parse(url).host
  def initials = label.split(/[\s.\-]+/).first(2).map { it[0] }.join.upcase

  # Its counts and look, asked for at most once a minute (Workspaces::RailsController asks for all
  # of a person's at once, in threads). A workspace that doesn't answer keeps what it last said.
  def fetch_badges
    return if !linked? || (badges_at && badges_at > BADGE_TTL.ago)

    self.class.request(:get, "#{url}/workspace/badge", key: remote_key)
  end

  def store_badges(data)
    attributes = { badges_at: Time.current }
    if data
      attributes.merge!(self.class.identity_attributes(data))
      attributes[:unread_count] = data["unread"].to_i
      attributes[:intake_count] = data["intake"].to_i
    end
    update_columns(attributes)
  end

  # Off the rail, here and, if it answers, there.
  def unlink!
    self.class.request(:delete, "#{url}/workspace/handshake", key: remote_key) if linked?
    destroy!
  end
end
