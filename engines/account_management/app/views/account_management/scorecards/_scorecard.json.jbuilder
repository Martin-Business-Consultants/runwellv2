json.user agent_user(scorecard.user)
json.days scorecard.days
json.meets_playbook scorecard.met?
json.clients(scorecard.clients.map { agent_ref(it) })
json.measures scorecard.measures do |measure|
  json.extract! measure, :key, :label, :target, :kept, :total, :percent
  json.met measure.met?
end
json.overdue_commitments scorecard.overdue_commitments.size
json.accounts_needing_attention scorecard.accesses_needing_attention.size
