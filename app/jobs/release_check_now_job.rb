# Settings > Updates' Check now, away from the request: asks GitHub for the newest release, or
# keeps GitHub's error for the page to show.
class ReleaseCheckNowJob < ApplicationJob
  def perform
    Release.check!
  rescue Release::Github::Error => error
    Setting.first.update!(release_check_error: error.message)
  end
end
