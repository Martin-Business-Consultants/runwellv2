# Installs an in-place update (Upgrade::InPlace) away from the request that asked for it.
class UpgradeJob < ApplicationJob
  def perform(upgrade)
    upgrade.runner.install if upgrade.running?
  end
end
