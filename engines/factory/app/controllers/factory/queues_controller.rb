# Queuing every piece of an engagement's work that an agent can take, in one go.
module Factory
  class QueuesController < ApplicationController
    require_permission :queue_agent_work
    agent_tool :queue_engagement_work, on: :create, title: "Hand all of an engagement's ready work to agents",
      description: "Queues every open todo on the engagement that is ready for an agent and not queued yet. The answer says how many."

    def create
      engagement = ::Engagement.find_by_ref!(params[:engagement_ref])
      queued = Events.queue_ready(engagement, by: Current.user)
      notice = queued.any? ? "Queued #{queued.size} for agents on #{engagement.ref}." : "Nothing on #{engagement.ref} is ready for an agent that isn’t queued already."
      redirect_back fallback_location: engagement, notice: notice
    end
  end
end
