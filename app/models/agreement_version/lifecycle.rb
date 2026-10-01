# Send, approve, request changes. Approval is what turns scope into work.
module AgreementVersion::Lifecycle
  extend ActiveSupport::Concern

  # Freeze the terms: snapshot the items and price, hash it, stamp sent_at.
  def send!(actor:, source: Current.source || "app", superseding: true)
    raise ArgumentError, "already sent" if sent?
    raise ArgumentError, "#{engagement.client.name} is internal: its projects have no agreement to send" if engagement.internal?
    raise ArgumentError, "nothing to send: add at least one item" if scope_items.empty? && !kind.in?(%w[revision])

    transaction do
      if superseding
        engagement.agreement_versions.select(&:awaiting_decision?).each { |v| v.update!(superseded_by_id: id) }
      end
      self.amount_cents = items_total_cents unless kind == "revision"
      self.price_delta_cents = initial? ? 0 : (kind == "revision" ? amount_cents - engagement.current_version&.amount_cents.to_i : items_total_cents)
      self.snapshot = build_snapshot
      self.content_hash = Digest::SHA256.hexdigest(snapshot.to_json)
      self.sent_at = Time.current
      self.sent_by = actor
      save!
      record_event!("agreement.sent", actor: actor, source: source, payload: { version: number, kind: kind, amount_cents: amount_cents })
      engagement.record_event!("agreement.sent", actor: actor, source: source, payload: { version: number })
    end
    self
  end

  # A human records the client's decision (by link, or from evidence like a
  # forwarded email). Approving turns each scope item into a todo.
  def decide!(decision:, method:, contact: nil, approver_name: nil, approver_email: nil, comment: nil,
              evidence: nil, ip_address: nil, user_agent: nil, recorded_by: nil, source: Current.source || "app")
    raise ArgumentError, "not sent" unless sent?
    raise ArgumentError, "already decided" if approval.present?
    raise ArgumentError, "superseded" if superseded_by_id.present?

    transaction do
      create_approval!(decision: decision, method: method, contact: contact,
                       approver_name: approver_name || contact&.name, approver_email: approver_email || contact&.email,
                       comment: comment, evidence: evidence, ip_address: ip_address, user_agent: user_agent,
                       content_hash: content_hash, decided_at: Time.current, recorded_by: recorded_by)
      record_event!("agreement.#{decision}", actor: recorded_by, source: source,
                    payload: { version: number, by: approver_name || contact&.name, method: method })
      engagement.record_event!("agreement.#{decision}", actor: recorded_by, source: source, payload: { version: number })
      spawn_todos! if decision == "approved"
    end
    approval
  end

  def issue_link!(contact, expires_in: 30.days)
    approval_links.create!(contact: contact, token: SecureRandom.urlsafe_base64(32), expires_at: expires_in.from_now)
  end

  private

  def build_snapshot
    {
      engagement: { ref: engagement.ref, title: engagement.title, label: engagement.label, shape: engagement.shape },
      client: engagement.client.name,
      version: number, kind: kind, summary: summary, reason: reason, cadence: cadence,
      items: scope_items.map { |i| { description: i.description, price_cents: i.price_cents } },
      amount_cents: amount_cents, price_delta_cents: price_delta_cents,
      description: engagement.description
    }
  end

  # Every approved scope item becomes a piece of work to track.
  def spawn_todos!
    scope_items.each do |item|
      next if item.todos.exists?

      engagement.todos.create!(scope_item: item, title: item.description, created_by: recorded_by_for_todos)
    end
  end

  def recorded_by_for_todos = approval&.recorded_by
end
