json.merge! agent_ref(issue)
json.extract! issue, :title, :state, :url, :environment, :found_live, :root_cause, :created_at, :fixed_at, :verified_at
json.steps agent_text(issue.steps)
json.expected agent_text(issue.expected)
json.actual agent_text(issue.actual)
json.fix_note agent_text(issue.fix_note)
json.client agent_ref(issue.client)
json.engagement agent_ref(issue.engagement)
json.todo agent_ref(issue.todo)
json.check agent_ref(issue.check)
json.assignee agent_user(issue.assignee)
json.opened_by agent_user(issue.opened_by)
json.fixed_by agent_user(issue.fixed_by)
json.verified_by issue.verified_by_run ? issue.verified_by_run.tester_label : issue.verified_by&.display_name
