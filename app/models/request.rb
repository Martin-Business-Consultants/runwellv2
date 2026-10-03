# Something a client asked for that we have not dealt with yet. It is
# evidence, not work: triage turns it into scope, a change order, a todo or a
# commitment, or dismisses it.
class Request < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable

  mentionable_fields :body

  STATUSES = %w[open promoted dismissed].freeze

  belongs_to :client, optional: true
  belongs_to :contact, optional: true
  belongs_to :promoted, polymorphic: true, optional: true
  belongs_to :triaged_by, class_name: "User", optional: true

  validates :subject, :source, presence: true
  validates :status, inclusion: { in: STATUSES }
  before_validation { self.received_at ||= Time.current }
  before_validation :match_contact

  scope :open, -> { where(status: "open") }
  scope :ordered, -> { order(received_at: :desc) }

  def self.filtered(status: "open", source: "all")
    scope = status == "all" ? all : where(status: status)
    scope = scope.where(source: source) unless source == "all"
    scope.ordered.includes(:client, :contact)
  end

  def self.sources = distinct.order(:source).pluck(:source)

  def open? = status == "open"
  def unmatched? = client_id.nil?

  def requester_name = contact&.name || sender_name.presence || sender_email

  # Proves a reply by email is to this request (RequestsMailbox): in its plus address and the
  # acknowledgement's Message-ID. Derived from the app's secret, so nothing is stored.
  def reply_token = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "request-reply:#{id}").first(12)

  def self.find_by_reply_token(id, token)
    request = find_by(id: id)
    request if request && ActiveSupport::SecurityUtils.secure_compare(request.reply_token, token.to_s.downcase)
  end

  # Draft an engagement whose first scope item is the request.
  def promote_to_engagement!(label:, actor:, title: nil, shape: "fixed")
    raise ArgumentError, "request has no client" unless client

    transaction do
      engagement = client.engagements.create!(label: label, shape: shape, title: title.presence || subject,
                                              description: body, created_by: actor)
      version = engagement.draft_version!(actor: actor)
      version.scope_items.create!(description: subject, price_cents: 0)
      promote!(engagement, actor)
      engagement
    end
  end

  # Add the request as a new item on the engagement's open draft, opening a
  # change order if there is none.
  def promote_to_change!(engagement:, actor:, price_cents: 0)
    transaction do
      version = engagement.draft_version || engagement.draft_version!(actor: actor, summary: subject, reason: "Requested by #{requester_name}")
      item = version.scope_items.create!(description: subject, price_cents: price_cents)
      promote!(version, actor)
      item
    end
  end

  def promote_to_todo!(engagement:, actor:, owner: nil, due_on: nil)
    transaction do
      todo = engagement.todos.create!(title: subject, description: body, owner: owner, due_on: due_on, created_by: actor)
      promote!(todo, actor)
      todo
    end
  end

  def promote_to_commitment!(actor:, due_on:, owner_kind: "us", user: nil, engagement: nil)
    raise ArgumentError, "request has no client" unless client

    transaction do
      commitment = client.commitments.create!(description: subject, due_on: due_on, owner_kind: owner_kind,
                                              user: user, contact: (owner_kind == "client" ? contact : nil),
                                              engagement: engagement, source: source)
      promote!(commitment, actor)
      commitment
    end
  end

  def dismiss!(reason:, actor:)
    raise ArgumentError, "already triaged" unless open?

    transaction do
      update!(status: "dismissed", dismissed_reason: reason, triaged_by: actor, triaged_at: Time.current)
      record_event!("request.dismissed", actor: actor, source: source, payload: { reason: reason })
    end
  end

  def promoted_label
    case promoted
    when Engagement then "#{promoted.ref} #{promoted.title}"
    when AgreementVersion then "#{promoted.engagement.ref} #{promoted.label}"
    when Todo then "Work: #{promoted.title}"
    when Commitment then "Commitment: #{promoted.description}"
    end
  end

  def search_title = subject
  def search_content = [ body, sender_name, sender_email ].compact_blank.join(" ")

  private

  def promote!(target, actor)
    raise ArgumentError, "already triaged" unless open?

    update!(status: "promoted", promoted: target, triaged_by: actor, triaged_at: Time.current)
    record_event!("request.promoted", actor: actor, source: source, payload: { to: target.class.name, id: target.id })
  end

  def match_contact
    return if contact || sender_email.blank?

    self.contact = Contact.find_by(email: sender_email.strip.downcase)
    self.client ||= contact&.client
  end
end
