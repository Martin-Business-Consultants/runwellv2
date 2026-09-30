class QuickActionsController < ApplicationController
  allow_staff
  agent_exempt :new, reason: "the quick action modal; add_note, add_document and log_time cover it"

  # The quick action form in a modal, loaded into the tray's frame, on the record picked at
  # the top of the tray (or the nearest one the action takes).
  def new
    @action = QuickAction.find(params[:kind])
    @record = @action.target_for(QuickAction.locate(params[:record], QuickAction::RECORD_TYPES)) if params[:record].present?
  end
end
