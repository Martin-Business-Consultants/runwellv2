# A quick action picker's choices for what was typed into it (quick_actions/record_picker, a
# combobox searching the server): matching clients, work and tasks by name, ref or title
# (QuickAction.search), as JSON by kind. Pickers start with a dozen recently changed records (less
# the one they hold, record=, which they list already) and find the rest here, so no page carries
# every record.
class QuickActions::RecordsController < ApplicationController
  allow_staff
  agent_exempt :index, reason: "a picker's search as you type; search and resolve answer agents"

  def index
    types = params[:types].to_s.split(",") & QuickAction::RECORD_TYPES
    types = QuickAction::RECORD_TYPES if types.empty?
    query = params[:q].to_s.strip
    records = query.present? ? QuickAction.search(query, types) : QuickAction.records(nil, types) - [ current ]
    render json: helpers.quick_action_record_items(records)
  end

  private
    def current
      QuickAction.locate(params[:record], QuickAction::RECORD_TYPES) if params[:record].present?
    rescue ActiveRecord::RecordNotFound, ActionController::BadRequest
      nil
    end
end
