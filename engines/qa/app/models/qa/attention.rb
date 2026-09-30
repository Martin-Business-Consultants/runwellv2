module Qa
  # What QA puts on a person's home page: checks failing, facts about to expire (a promo that
  # ends Tuesday), issues they have to fix, fixes waiting for them to verify, and checks overdue
  # for a test. A check with an owner goes to its owner; one without goes to whoever may manage QA.
  module Attention
    extend self

    def items(user)
      checks = Check.active.includes(:client, :owner, :expectations).select { responsible?(user, it) }
      checks.select(&:failing?) +
        checks.flat_map { |check| check.expectations.select { it.expiring?(within: 7.days) } } +
        Issue.open.where(assignee: user).includes(:client).recent.to_a +
        Issue.fixed.includes(:client, :check).recent.select { verifiable_by?(user, it) } +
        checks.select(&:due?)
    end

    def responsible?(user, check) = check.owner ? check.owner == user : user.can?(:manage_qa)

    def verifiable_by?(user, issue)
      issue.fixed_by != user && (user.can?(:manage_qa) || issue.check&.owner == user || issue.opened_by == user)
    end
  end
end
