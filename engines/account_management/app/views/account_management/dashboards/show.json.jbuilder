json.summary "#{pluralize(@scorecards.size, "lead")}, #{@scorecards.count(&:met?)} meeting the playbook; #{pluralize(@agendas_due.size, "agenda")} and #{pluralize(@recaps_due.size, "recap")} due; #{pluralize(@accesses.size, "account")} needing attention; #{pluralize(@unled.size, "client")} without a lead"
json.scorecards @scorecards do |scorecard|
  json.partial! "account_management/scorecards/scorecard", scorecard: scorecard
end
json.agendas_due @agendas_due, partial: "account_management/meetings/meeting", as: :meeting
json.recaps_due @recaps_due, partial: "account_management/meetings/meeting", as: :meeting
json.accesses_needing_attention @accesses, partial: "account_management/accesses/access", as: :access
json.clients_without_lead(@unled.map { agent_ref(it) })
