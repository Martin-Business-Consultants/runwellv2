class Approval < ApplicationRecord
  DECISIONS = %w[approved changes_requested].freeze
  # link: the client clicked (emailed link or portal); agent: their own agent did, with their typed
  # name (Portal::ApprovalsController); recorded: we recorded it with evidence.
  METHODS = %w[link agent recorded].freeze

  belongs_to :agreement_version
  belongs_to :contact, optional: true
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :decision, inclusion: { in: DECISIONS }
  validates :method, inclusion: { in: METHODS }
  validates :evidence, presence: true, if: -> { method == "recorded" }

  before_update { raise ActiveRecord::ReadOnlyRecord, "approvals are immutable" }
  before_destroy { throw :abort unless Current.erasing }
end
