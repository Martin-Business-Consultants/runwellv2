json.summary "#{@setup.done_count} of #{@setup.steps.size} setup steps done"
json.complete @setup.complete?
json.steps @setup.steps do |step|
  json.extract! step, :key, :title, :text, :done, :optional
  json.url "#{request.base_url}#{step.path}"
end
