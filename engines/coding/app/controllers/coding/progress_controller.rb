# Reporting on a todo from the terminal: a note on it, and optionally its status and branch.
module Coding
  class ProgressController < ApplicationController
    allow_staff
    agent_tool :log_progress, on: :create, title: "Report progress on a todo",
      description: "Adds a note to the todo. status moves it (planned, in_progress, in_review, blocked, done). branch and pull_request_url record where the work is.",
      params: { progress: { note: "text!", status: ::Todo::STATUSES, branch: "string", pull_request_url: "string" } }

    before_action :set_todo

    def create
      progress = params.expect(progress: %i[note status branch pull_request_url])
      return redirect_back(fallback_location: @todo, alert: "Say what happened.") if progress[:note].blank?

      ::Todo.transaction do
        @todo.notes.create!(body: progress[:note], kind: "internal", source: Current.source || "app", author: Current.user)
        Branch.record!(@todo, name: progress[:branch], pull_request_url: progress[:pull_request_url])
        @todo.update!(status: progress[:status]) if progress[:status].present? && progress[:status] != @todo.status
        @todo.record_event!("coding.progress", payload: { branch: progress[:branch] })
      end
      redirect_back fallback_location: @todo, notice: "Progress noted on “#{@todo.title}” (#{@todo.status.humanize.downcase})."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: @todo, alert: e.record.errors.full_messages.to_sentence
    end
  end
end
