# A quick action picker's choices for what was typed into it, into the picker's list frame:
# matching clients, engagements and work by name, ref or title (QuickAction.search). Pickers start
# with a dozen records and find the rest here, so no page carries every record.
class QuickActions::RecordsController < ApplicationController
  allow_staff
  agent_exempt :index, reason: "a picker's search as you type; search and resolve answer agents"

  def index
    types = params[:types].to_s.split(",") & QuickAction::RECORD_TYPES
    types = QuickAction::RECORD_TYPES if types.empty?
    query = params[:q].to_s.strip
    @records = query.present? ? QuickAction.search(query, types) : QuickAction.records(nil, types)
    @frame = "#{params[:form_id].to_s.gsub(/[^a-z_]/, "")}_records"
    render layout: false
  end
end
