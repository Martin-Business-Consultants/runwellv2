json.merge! agent_ref(access)
json.extract! access, :platform, :name, :external_id, :url, :owned_by, :owner_name, :our_access, :login_location, :token_expires_on, :verified_on
json.platform_label access.platform_label
json.owned_by_label access.owned_by_label
json.problems access.problems
json.notes agent_text(access.notes)
json.client agent_ref(access.client)
json.verified_by agent_user(access.verified_by)
