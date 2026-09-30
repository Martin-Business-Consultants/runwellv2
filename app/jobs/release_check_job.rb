# Nightly: asks GitHub for the newest release, so Settings > Updates and the owners' home page
# can say one is out, and settles any update that finished or went quiet.
class ReleaseCheckJob < ApplicationJob
  def perform
    Release.check! if Release.checking?
  rescue Release::Github::Error => error
    Rails.logger.warn "[updates] #{error.message}"
  ensure
    Upgrade.reconcile
  end
end
