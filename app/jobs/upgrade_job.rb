# Starts an update away from the request that asked for it: an in-place install, a GitHub
# deploy, or bin/update in the background (Upgrade#run).
class UpgradeJob < ApplicationJob
  def perform(upgrade)
    upgrade.run if upgrade.running?
  end
end
