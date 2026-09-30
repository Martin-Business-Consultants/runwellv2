json.summary "A lead owns the relationship, scope and planning, quality, accounts and access, and the weekly report. Targets: agendas #{(AccountManagement::Playbook::AGENDA_AHEAD / 1.hour).round}h ahead #{AccountManagement::Playbook::TARGETS[:agendas]}%, recaps within #{(AccountManagement::Playbook::RECAP_WITHIN / 1.hour).round}h #{AccountManagement::Playbook::TARGETS[:recaps]}%, commitments by their date #{AccountManagement::Playbook::TARGETS[:commitments]}%, weekly update by Friday #{AccountManagement::Playbook::TARGETS[:updates]}%."
json.targets AccountManagement::Playbook::TARGETS
json.agenda_ahead_hours (AccountManagement::Playbook::AGENDA_AHEAD / 1.hour).round
json.recap_within_hours (AccountManagement::Playbook::RECAP_WITHIN / 1.hour).round
json.token_warning_days (AccountManagement::Playbook::TOKEN_WARNING / 1.day).round
json.verify_every_days (AccountManagement::Playbook::VERIFY_EVERY / 1.day).round
json.owns [
  "The relationship: agenda before every meeting, recap after with action items, commitments closed by their date",
  "Scope and planning: nothing starts without agreed scope, owners and dates; client content and approvals in writing first",
  "Quality: nothing ships until checked against the client's source of truth; root cause and checklist change for every escape",
  "Accounts and access: every outside account in the register; confirm ownership before removing anyone; no token expires unnoticed",
  "Coordination and reporting: nobody blocked on client info; risks raised early; written weekly update by Friday"
]
