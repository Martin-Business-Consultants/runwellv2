module Coding
  # Someone GitHub says can reach a repo, as of the last sync. Kept to catch people who have
  # left: a deactivated person who still has access shows on home until it is removed.
  class Collaborator < ::ApplicationRecord
    self.table_name = "coding_collaborators"

    belongs_to :repository

    # People deactivated in Runwell whose GitHub login can still reach a linked repo.
    scope :departed, -> {
      where(login: Identity.joins(:user).where.not(users: { deactivated_at: nil }).select(:github_login))
    }

    def identity = Identity.find_by(github_login: login)
    def label = "#{identity&.user&.display_name || login} can still reach #{repository.name}"
  end
end
