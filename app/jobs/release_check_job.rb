# Nightly: asks GitHub for the newest release of Runwell and of each installed plugin, so
# Settings > Updates, Settings > Plugins and the owners' home page can say one is out, and settles
# any update or plugin change that finished or went quiet.
class ReleaseCheckJob < ApplicationJob
  def perform
    if Release.checking?
      check { Release.check! }
      check { PluginRelease.check! }
    end
  ensure
    Upgrade.reconcile
    PluginChange.reconcile
  end

  private
    def check
      yield
    rescue Release::Github::Error => error
      Rails.logger.warn "[updates] #{error.message}"
    end
end
