json.summary "#{@user.display_name}, #{@user.person.role}#{" (via #{Current.access_token.name})" if Current.agent?}#{", acting for #{@user.person.display_name}" if @user.agent?}#{", read only" if Current.access_token&.read_only?}"
json.me do
  json.merge! agent_user(@user)
  json.extract! @user, :email_address
  json.role @user.person.role
  json.acting_for(agent_user(@user.person)) if @user.agent?
end
json.read_only Current.access_token&.read_only? || false
json.can(Current.access_token&.read_only? ? [] : User.permissions.keys.select { @user.can?(it) })
json.cannot(User.permissions.reject { |key, _| @user.can?(key) }.transform_values { it[:name] })
json.team @team do |person|
  json.merge! agent_user(person)
  json.role person.role
end
json.plugins_on Runwell::Plugins.manifests.keys.select { Runwell::Plugins.enabled?(it) }
json.workflows(Runwell::Plugins.enabled_agent_workflows.map { |key, (title, text)| { plugin: key, title: title, steps: text.strip } })
json.withheld_tools @withheld.map { |tool| { name: tool.name, why: tool.plugin && !Runwell::Plugins.enabled?(tool.plugin) ? "the #{tool.plugin} plugin is off" : "needs #{tool.permissions.join(", ")}" } }
json.terms(Setting::TERMS.to_h { [ it, term(it.to_sym) ] })
