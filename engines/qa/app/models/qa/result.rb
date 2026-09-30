module Qa
  # What one run saw for one expectation. The expectation's label and expected value are
  # copied in, so the result still says what was checked after the source of truth changes.
  class Result < ::ApplicationRecord
    belongs_to :run
    belongs_to :expectation, optional: true

    scope :failed, -> { where(passed: false) }

    before_update { raise ActiveRecord::ReadOnlyRecord, "results are never changed" }
  end
end
