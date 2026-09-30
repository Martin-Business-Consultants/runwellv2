module Coding
  # What the home page shows for code: open pull requests with failing checks, the latest
  # deploy to an environment when it failed, and people who have left but can still reach a
  # linked repo.
  module Attention
    def self.items
      latest = Deploy.where(id: Deploy.group(:repository_id, :environment).select("max(id)"))
      Branch.failing.includes(:repository, todo: :engagement).order(:updated_at).to_a +
        latest.failed.includes(:repository).recent.to_a.uniq { [ it.repository.full_name, it.environment ] } +
        Collaborator.departed.includes(:repository).order(:login).to_a.uniq { [ it.repository.full_name, it.login ] }
    end
  end
end
