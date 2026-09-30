# Putting a QA check on a piece of work, so it can't be marked done until the check passes
# again, and taking it off (only for someone who may manage QA: whoever built the work doesn't
# get to remove its gate).
module Qa
  class GatesController < ApplicationController
    allow_staff
    require_permission :manage_qa, only: :destroy
    agent_tool :gate_work_on_qa_check, on: :create, title: "Require a QA check to pass before work is done",
      description: "The work can't be marked done until every expectation on the check passes in a test after the work last went to review, by someone other than its owner (the nightly page check and the site's own report count).",
      params: { gate: { check_id: "integer!" } }
    agent_tool :remove_qa_gate, on: :destroy, title: "Take a QA check off a piece of work"

    before_action { @todo = ::Todo.find(params[:todo_id]) }

    def create
      gate = @todo.qa_gates.new(check: Check.active.find_by(id: params.dig(:gate, :check_id)), created_by: Current.user)
      if gate.save
        @todo.record_event!("qa.gated", payload: { check: gate.check.name })
        redirect_back fallback_location: todo_path(@todo), notice: "#{gate.check.name} must pass before this is done."
      else
        redirect_back fallback_location: todo_path(@todo), alert: gate.errors.full_messages.to_sentence.presence || "Choose a check."
      end
    end

    def destroy
      gate = @todo.qa_gates.find(params[:id])
      gate.destroy!
      @todo.record_event!("qa.ungated", payload: { check: gate.check.name })
      redirect_back fallback_location: todo_path(@todo), notice: "#{gate.check.name} no longer holds this up."
    end
  end
end
