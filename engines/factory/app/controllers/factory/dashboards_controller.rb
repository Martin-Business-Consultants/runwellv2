# The factory at a glance: what's running, what's queued, what needs a person, recent runs,
# and this month's spend against the budget.
module Factory
  class DashboardsController < ApplicationController
    allow_staff
    agent_tool :show_factory, on: :show, title: "Show the factory: running, queued and recent agent runs",
      description: "What runners are working on now, the queue in the order runners will take it (earliest due first), work that needs a person (failed, blocked, waiting for review), recent runs, and this month's spend."

    def show
      Run.expire_stale!
      @policy = Policy.current
      @items = Item.with_todo.includes(:runs, :queued_by).to_a.group_by(&:state)
      @queue = Queue.new.candidates.select(&:claimable?)
      @recent = Run.recent.includes(:claimed_by, todo: { engagement: :client }).limit(20)
    end
  end
end
