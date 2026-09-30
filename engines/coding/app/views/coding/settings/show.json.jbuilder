json.summary @connection.connected? ? "Connected to GitHub as @#{@connection.login}; #{@repositories.size} linked #{"repository".pluralize(@repositories.size)}" : "GitHub not connected: #{@connection.blocker}"
json.connected @connection.connected?
json.login @connection.login
json.blocker @connection.blocker
json.last_error @connection.last_error
json.last_synced_at @connection.last_synced_at
json.issue_label @connection.issue_label
json.close_work_on_merge @connection.close_work_on_merge
json.webhook_url coding_github_webhooks_url
json.people @people do |person|
  json.merge! agent_user(person)
  json.github_login person.coding_identity&.github_login
end
json.repositories @repositories do |repository|
  json.merge! agent_ref(repository).except("url")
  json.extract! repository, :url, :default_branch, :share_deploys
  json.webhook repository.webhook_id.present?
  json.linked_to agent_ref(repository.linkable)
end
