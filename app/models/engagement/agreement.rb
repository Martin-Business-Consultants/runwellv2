# Derived state and the current agreed terms. State is never typed in; it is
# read off the versions and approvals. An internal client's engagements (your own
# projects) have no agreement to send, so they are "internal" from the start.
module Engagement::Agreement
  extend ActiveSupport::Concern

  STATES = %w[draft sent changes_requested approved internal closed].freeze

  # The latest version a client approved: the terms in force.
  def current_version
    agreement_versions.reverse.find(&:approved?)
  end

  def draft_version
    agreement_versions.reverse.find(&:draft?)
  end

  def pending_version
    agreement_versions.reverse.find(&:awaiting_decision?)
  end

  def approved_versions = agreement_versions.select(&:approved?)

  def state
    return "closed" if closed?
    return "internal" if internal?

    latest = agreement_versions.last
    return "draft" if latest.nil? || latest.draft?
    return "sent" if latest.awaiting_decision?
    return "changes_requested" if latest.changes_requested?

    "approved"
  end

  def approved? = current_version.present?

  # Your own project: no agreement, price or approval.
  def internal? = client&.internal? || false

  # Underway: agreed with the client, or internal.
  def active? = state.in?(%w[approved internal])

  # Fixed scope: initial amount plus every approved change. Recurring: the
  # latest approved amount per period.
  def agreed_amount_cents
    versions = approved_versions
    return 0 if versions.empty?
    return versions.last.amount_cents if recurring?

    versions.sum { |v| v.kind == "initial" ? v.amount_cents : v.price_delta_cents }
  end

  # The scope in force: every item from every approved version.
  def agreed_items
    approved_versions.flat_map { |v| v.scope_items.to_a }
  end

  def next_version_number = (agreement_versions.maximum(:number) || 0) + 1

  # A new draft. The first is `initial`; later ones are change orders (fixed)
  # or revisions / add-ons (recurring). Nothing is copied: a change order lists
  # only what changes.
  def draft_version!(kind: nil, summary: nil, reason: nil, actor: Current.user)
    raise ArgumentError, "a draft is already open" if draft_version

    kind ||= agreement_versions.none? ? "initial" : (recurring? ? "revision" : "change_order")
    agreement_versions.create!(kind: kind, number: next_version_number, summary: summary, reason: reason,
                               cadence: (recurring? ? (current_version&.cadence || "monthly") : nil),
                               amount_cents: (kind == "revision" ? current_version&.amount_cents.to_i : 0))
  end
end
