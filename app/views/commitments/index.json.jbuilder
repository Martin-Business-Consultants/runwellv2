json.summary "#{pluralize(@commitments.size, "commitment")} (#{@state})"
json.commitments @commitments, partial: "commitments/commitment", as: :commitment
