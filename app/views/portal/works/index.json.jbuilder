json.summary "#{pluralize @works.size, term(:work).downcase} with #{client.name} (#{@state})"
json.works @works do |work|
  progress = @progress[work.id]
  json.merge! portal_agent_ref(work)
  json.extract! work, :title
  json.label work.label_name
  json.state work.state
  json.your_priority work.client_priority
  json.tasks_done progress[:done]
  json.tasks_total progress[:total]
  json.next_due_on progress[:next_due]
end
