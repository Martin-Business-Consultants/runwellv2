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
end
