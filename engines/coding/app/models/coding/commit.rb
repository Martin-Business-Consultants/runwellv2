module Coding
  # A commit pushed to a todo's branch, kept so time can be suggested from it.
  class Commit < ::ApplicationRecord
    self.table_name = "coding_commits"

    belongs_to :repository
    belongs_to :todo, class_name: "::Todo", optional: true
    belongs_to :user, class_name: "::User", optional: true

    scope :unsettled, -> { where(logged_at: nil, dismissed_at: nil).where.not(todo_id: nil).where.not(user_id: nil) }
  end
end
