# Settings > Factory: limits, the budget, queuing on approval, which clients never get agent
# work, and how to start a runner.
module Factory
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_factory_settings, on: :show, title: "Show the factory's limits and settings"
    agent_tool :update_factory_settings, on: :update, title: "Change the factory's limits and settings",
      description: "max_concurrent_runs, lease_minutes (between heartbeats), run_time_limit_minutes, max_attempts per todo, monthly_budget_cents (blank for none), queue_on_approval (an approved agreement queues its ready work), blocked_client_ids (clients that never get agent work).",
      params: { policy: { max_concurrent_runs: "integer", lease_minutes: "integer", run_time_limit_minutes: "integer", max_attempts: "integer",
                          monthly_budget_cents: "integer", queue_on_approval: "boolean", blocked_client_ids: [ "integer" ] } }

    before_action { @policy = Policy.current }

    def show
      @clients = ::Client.active.ordered
    end

    def update
      attributes = params.expect(policy: [ :max_concurrent_runs, :lease_minutes, :run_time_limit_minutes, :max_attempts,
                                           :monthly_budget_cents, :queue_on_approval, blocked_client_ids: [] ])
      attributes[:blocked_client_ids] = Array(attributes[:blocked_client_ids]).compact_blank.map(&:to_i) if attributes.key?(:blocked_client_ids)
      attributes[:monthly_budget_cents] = attributes[:monthly_budget_cents].presence if attributes.key?(:monthly_budget_cents)

      if @policy.update(attributes)
        redirect_to factory_settings_path, notice: "Factory settings saved."
      else
        redirect_to factory_settings_path, alert: @policy.errors.full_messages.to_sentence
      end
    end
  end
end
