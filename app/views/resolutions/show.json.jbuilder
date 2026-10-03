json.summary(case @candidates.size
when 0 then "Nothing matches “#{@query}”. Try search for a wider look."
when 1 then "“#{@query}” is #{Agent::Resolver.describe(@candidates.first)["name"]}."
else "#{@candidates.size} records match “#{@query}”: ask the person which they mean if it isn't clear."
end)
json.candidates @candidates do |record|
  json.merge! agent_ref(record)
  json.merge! Agent::Resolver.describe(record).slice("name", "client")
end
