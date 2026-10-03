module AgreementsHelper
  # What a version puts in front of the client: the whole price, a change, or a new recurring price.
  def version_amount(version)
    cents = version.draft? ? version.items_total_cents : version.amount_cents
    if version.kind == "revision"
      [ money(version.amount_cents), version.cadence ].compact.join(" / ")
    elsif version.initial?
      money(cents)
    else
      "+#{money(version.draft? ? cents : version.price_delta_cents)}"
    end
  end

  # Approvers first, so the likely choice is at the top.
  def contact_options(contacts, email_only: false)
    contacts = contacts.select { |contact| contact.email.present? } if email_only
    contacts.sort_by { |contact| [ contact.can_approve? ? 0 : 1, contact.name ] }
            .map { |contact| [ [ contact.name, ("can approve" if contact.can_approve?) ].compact.join(" · "), contact.id ] }
  end

  def default_approver(contacts)
    contacts.find { |contact| contact.can_approve? && contact.email.present? }&.id
  end

  def new_version_kinds(engagement)
    if engagement.agreement_versions.none? then [ [ "Agreement", "initial" ] ]
    elsif engagement.recurring? then [ [ "Revision (new recurring price)", "revision" ], [ "Add-on", "add_on" ] ]
    else [ [ "Change order", "change_order" ] ]
    end
  end

  # Money shows only where there is some, and only while the install keeps prices (Settings >
  # Names, Setting#prices): an agreement of $0 items reads as a list of what's agreed, no total.
  def prices_on? = Setting.current.prices?

  def priced_version?(version)
    return false unless prices_on?

    items = version.sent? ? Array(agreement_snapshot(version)["items"]).map { it["price_cents"].to_i } : version.scope_items.map(&:price_cents)
    items.any?(&:nonzero?) || version.amount_cents.to_i.nonzero? || agreement_total_cents(version).to_i.nonzero?
  end

  def priced_engagement?(engagement) = prices_on? && engagement.agreed_amount_cents.nonzero?

  # "$1,200" or "$1,200 / period" for an engagement, or nothing when it has no price to show.
  def engagement_amount(engagement, per: " / period")
    return unless priced_engagement?(engagement)

    money(engagement.agreed_amount_cents) + (engagement.recurring? ? per : "")
  end
end
