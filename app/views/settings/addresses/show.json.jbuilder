json.summary "Links in email point to #{Runwell.url}#{" (not set: guessed)" unless Runwell.host_set?}"
json.url Runwell.url
json.host Runwell.host
json.protocol Runwell.protocol
json.set Runwell.host_set?
json.saved_host @setting.app_host
json.app_host_env ENV["APP_HOST"]
json.last_seen_host @setting.seen_host
