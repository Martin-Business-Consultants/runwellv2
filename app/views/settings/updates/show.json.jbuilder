json.summary(if @upgrade
  "Updating from #{@upgrade.from_version} to #{@upgrade.to_version}"
elsif @release&.newer?
  "Runwell #{Runwell::VERSION}; #{@release.version} is out#{Upgrade.available? ? " (update_runwell installs it)" : ", but updating from here isn't set up"}"
else
  "Runwell #{Runwell::VERSION}, the newest release"
end)
json.version Runwell::VERSION
json.updates_by Upgrade.via
json.checked_at Release.checked_at
json.checking Release.check_pending?
json.check_error Release.check_error
json.latest_release do
  if @release
    json.version @release.version
    json.newer @release.newer?
    json.url @release.url
    json.published_at @release.published_at
    json.notes @release.notes
  else
    json.nil!
  end
end
json.updates @upgrades do |upgrade|
  json.id upgrade.id
  json.from_version upgrade.from_version
  json.to_version upgrade.to_version
  json.status upgrade.status
  json.via upgrade.via
  json.requested_by upgrade.requested_by.display_name
  json.started_at upgrade.created_at
  json.finished_at upgrade.finished_at
  json.log_url upgrade.external_url
  json.message upgrade.message
end
