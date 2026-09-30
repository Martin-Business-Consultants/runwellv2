# Handing one todo to agents, with any extra instructions, and taking it back.
module Factory
  class ItemsController < ApplicationController
    require_permission :queue_agent_work
    agent_tool :queue_work, on: :create, title: "Hand a todo to agents",
      description: "Queues the todo for the next free runner. It must be ready: approved scope, a description or scope item, a linked repository (Code plugin) and a client that allows agent work; otherwise the answer says what to fix. instructions: anything extra the agent should know.",
      params: { item: { instructions: "text" } }
    agent_tool :unqueue_work, on: :destroy, title: "Take a todo back from agents",
      description: "Removes it from the queue. A run in progress is cancelled first. Past runs stay on the todo."

    before_action :set_todo

    def create
      readiness = Readiness.new(@todo)
      return redirect_back(fallback_location: @todo, alert: "Not ready for an agent: #{readiness.problems.to_sentence}") unless readiness.ready?

      Item.queue!(@todo, by: Current.user, instructions: params.dig(:item, :instructions))
      redirect_back fallback_location: @todo, notice: "“#{@todo.title}” is queued for an agent."
    end

    def destroy
      if (item = @todo.factory_item)
        item.current_run&.cancel!(by: Current.user)
        item.destroy!
        @todo.record_event!("factory.unqueued")
      end
      redirect_back fallback_location: @todo, notice: "“#{@todo.title}” is no longer queued for agents."
    end
  end
end
