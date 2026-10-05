json.merge! agent_ref(@person)
json.summary "#{@person.display_name}, #{@person.role}, #{@person.deactivated? ? "deactivated" : "active"}: #{pluralize(@sessions.size, "open session")}, #{pluralize(@connections.size, "connected app")}#{", two-factor on" if @person.two_factor?}."
json.extract! @person, :name, :email_address, :role
json.active @person.active?
json.two_factor @person.two_factor?
json.open_sessions @sessions.size
json.connected_apps(@connections) { |token| json.extract! token, :name, :kind, :last_used_at }
json.recent_sign_ins(@sign_ins) do |event|
  json.ok event.kind == "user.signed_in"
  json.at event.occurred_at
  json.method event.payload["method"]
end
