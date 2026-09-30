json.merge! agent_ref(agreement_version)
json.extract! agreement_version, :number, :kind, :summary, :reason, :cadence
json.label agreement_version.label
json.status agreement_version.status
json.draft agreement_version.draft?
json.awaiting_decision agreement_version.awaiting_decision?
json.amount money(agreement_version.draft? ? agreement_version.items_total_cents : agreement_version.amount_cents)
json.amount_cents(agreement_version.draft? ? agreement_version.items_total_cents : agreement_version.amount_cents)
json.sent_at agreement_version.sent_at
json.decision agreement_version.approval&.decision
json.scope_items agreement_version.scope_items.sort_by(&:position), partial: "scope_items/scope_item", as: :scope_item
