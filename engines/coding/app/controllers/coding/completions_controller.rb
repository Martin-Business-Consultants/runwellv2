# Finishing a todo from the terminal: what was done, where it is, and the todo put in review
# for a person to check. A merged pull request (or the person) marks it done.
module Coding
  class CompletionsController < ApplicationController
    allow_staff
    agent_tool :finish_work, on: :create, title: "Finish a todo for review, with a summary",
      description: "Adds the summary as a note, records the branch and pull request, and moves the todo to in_review for a person to check. Merging the pull request (or the person) marks it done.",
      params: { completion: { summary: "text!", branch: "string", pull_request_url: "string" } }

    before_action :set_todo

    def create
      completion = params.expect(completion: %i[summary branch pull_request_url])
      return redirect_back(fallback_location: @todo, alert: "Say what was done.") if completion[:summary].blank?

      ::Todo.transaction do
        @todo.notes.create!(body: completion[:summary], kind: "internal", source: Current.source || "app", author: Current.user)
        Branch.record!(@todo, name: completion[:branch], pull_request_url: completion[:pull_request_url])
        @todo.update!(status: "in_review")
        @todo.record_event!("coding.finished", payload: { branch: completion[:branch], pull_request: completion[:pull_request_url] })
      end
      redirect_back fallback_location: @todo, notice: "“#{@todo.title}” is ready for review."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: @todo, alert: e.record.errors.full_messages.to_sentence
    end
  end
end
