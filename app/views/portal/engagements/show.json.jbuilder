json.summary "#{@engagement.ref} #{@engagement.title}: #{@engagement.state.humanize.downcase}#{"; an agreement awaits your decision" if @pending}"
json.engagement do
  json.merge! portal_agent_ref(@engagement)
  json.extract! @engagement, :title
  json.label @engagement.label_name
  json.state @engagement.state
  json.agreed_cents @engagement.agreed_amount_cents
  json.agreed money(@engagement.agreed_amount_cents)
  json.per_period @engagement.recurring?
  json.description agent_text(@engagement.description)

  if @pending
    json.awaiting_your_decision do
      json.agreement agreement_snapshot(@pending)
      json.label @pending.label
      json.sent_at @pending.sent_at
      json.you_can_decide current_contact.can_approve?
      json.how(current_contact.can_approve? ? "Show the person the agreement above, then call portal_decide with their decision and their typed name." : "Someone at #{client.name} who can approve agreements needs to decide.")
    end
  else
    json.awaiting_your_decision nil
  end

  json.scope_in_force @engagement.agreed_items do |item|
    json.description item.description
    json.price_cents item.price_cents
    json.price money(item.price_cents)
    json.delivery item.delivery_state
  end

  json.agreements @engagement.agreement_versions.select(&:sent?).reverse do |version|
    json.label version.label
    json.sent_at version.sent_at
    json.agreement agreement_snapshot(version)
    if version.approval
      json.decision version.approval.decision
      json.decided_by version.approval.approver_name
      json.decided_at version.approval.decided_at
    end
  end

  json.work @engagement.todos.client_visible.order(:due_on) do |todo|
    json.title todo.title
    json.status todo.status
    json.due_on todo.due_on
  end

  json.documents @engagement.client_documents.includes(file_attachment: :blob) do |document|
    json.filename document.filename.to_s
    json.byte_size document.byte_size
    json.content_type document.content_type
    json.url rails_blob_url(document.file, disposition: :attachment)
  end
end
