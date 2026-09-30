module Coding
  # A deploy GitHub reported for a repo (deployment_status), newest state per deployment.
  class Deploy < ::ApplicationRecord
    self.table_name = "coding_deploys"

    PRODUCTION = %w[production prod live].freeze

    belongs_to :repository

    scope :recent, -> { order(deployed_at: :desc) }
    scope :succeeded, -> { where(state: "success") }
    scope :production, -> { where("lower(environment) IN (?)", PRODUCTION) }
    scope :failed, -> { where(state: %w[failure error]) }

    def production? = environment.to_s.downcase.in?(PRODUCTION)
    def succeeded? = state == "success"
    def label = "#{repository.name} to #{environment}"
  end
end
