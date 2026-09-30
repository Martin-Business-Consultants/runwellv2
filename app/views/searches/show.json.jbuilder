results = @search.results
json.summary @query ? "#{pluralize(results.size, "result")} for “#{@query}”" : "Give a query."
json.results results do |record|
  json.merge! agent_ref(record)
  json.context search_result_context(record)
  json.snippet strip_tags(record.hit.highlight(:content).to_s).presence
end
