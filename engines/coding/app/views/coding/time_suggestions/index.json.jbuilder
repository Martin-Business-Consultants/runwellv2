json.summary @suggestions.any? ? "#{@suggestions.size} #{"suggestion".pluralize(@suggestions.size)}, #{code_duration @suggestions.sum(&:minutes)} in all" : "Nothing to suggest"
json.time_tracking_on @time_tracking.present?
json.github_login Current.user.coding_identity&.github_login
json.suggestions @suggestions do |suggestion|
  json.id suggestion.id
  json.date suggestion.date
  json.minutes suggestion.minutes
  json.duration code_duration(suggestion.minutes)
  json.note suggestion.note
  json.todo agent_ref(suggestion.todo)
end
