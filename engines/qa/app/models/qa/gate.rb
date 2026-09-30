module Qa
  # A check a piece of work must pass before it can be marked done. Only tests since the work
  # last went to review count, and none by the work's own owner: whoever built it doesn't sign
  # it off. The page fetch and the site's own report count, since nobody built them.
  class Gate < ::ApplicationRecord
    belongs_to :todo, class_name: "::Todo"
    belongs_to :check
    belongs_to :created_by, class_name: "::User", optional: true

    validates :check_id, uniqueness: { scope: :todo_id, message: "is already on this work" }
    validate { errors.add(:check, "must be one of the client’s") if todo && check && check.client_id != todo.engagement.client_id }

    # Why the work can't be done yet, in words; empty when it can.
    def self.problems_for(todo)
      todo.qa_gates.includes(check: :expectations).flat_map(&:problems)
    end

    def since
      reviewed = todo.events.where(kind: "todo.status").where("json_extract(payload, '$.to') = 'in_review'").maximum(:occurred_at)
      [ created_at, reviewed ].compact.max
    end

    # The results that count for this gate, per expectation.
    def counted_results
      check.latest_results.select { |_, result| result.created_at >= since && (result.run.user.nil? || result.run.user != todo.owner) }
    end

    def problems
      return [ "#{check.name} has nothing to check yet" ] if check.expectations.empty?

      counted = counted_results
      failed = check.expectations.select { counted[it.id]&.passed == false }
      untested = check.expectations.reject { counted.key?(it.id) }
      [
        ("#{check.name}: #{failed.map(&:label).to_sentence} failed" if failed.any?),
        ("#{check.name}: #{untested.size == check.expectations.size ? "not tested" : "#{untested.map(&:label).to_sentence} not tested"} since this went to review#{" (by someone other than #{todo.owner.display_name})" if todo.owner}" if untested.any?)
      ].compact
    end

    def passed? = problems.empty?
  end
end
