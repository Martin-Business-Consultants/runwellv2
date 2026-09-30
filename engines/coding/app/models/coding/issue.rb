module Coding
  # A GitHub issue that became a request, so the same issue never arrives twice.
  class Issue < ::ApplicationRecord
    self.table_name = "coding_issues"

    belongs_to :repository
    belongs_to :request, class_name: "::Request", optional: true
  end
end
