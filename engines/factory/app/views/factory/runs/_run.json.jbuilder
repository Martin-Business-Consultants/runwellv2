json.merge! agent_ref(run)
json.extract! run, :status, :runner, :attempt, :started_at, :lease_expires_at, :heartbeat_at, :finished_at,
  :branch, :pull_request_url, :log_url, :summary, :error, :cost_cents, :input_tokens, :output_tokens
json.cost money(run.cost_cents)
json.deadline run.deadline if run.running?
json.todo agent_ref(run.todo)
json.claimed_by agent_user(run.claimed_by)
