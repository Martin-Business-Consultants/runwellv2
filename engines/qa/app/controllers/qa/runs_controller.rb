# Recording a test of a check, by a person or an agent, and reading one back.
module Qa
  class RunsController < ApplicationController
    allow_staff
    agent_tool :record_qa_test, on: :create, title: "Record a QA test of a check",
      description: "results: keyed by expectation key (show_qa_check lists them). For a value, give what you saw ({ \"actual\": \"hello@acme-storage.example\" }) and it is compared with the source of truth; for a step, { \"verdict\": \"pass\" } or { \"verdict\": \"fail\", \"actual\": \"what happened\" }. Leave out what you didn't test. A failure opens an issue; a pass verifies fixed issues on it. evidence_url: a screenshot, a test email, a render report.",
      params: { run: { results: {}, notes: "text", evidence_url: "string" } }
    agent_tool :show_qa_test, on: :show, title: "Show a QA test and what it saw"

    def create
      @check = Check.find(params[:check_id])
      attributes = params.expect(run: [ :notes, :evidence_url, results: {} ])
      run = Run.record(check: @check, answers: attributes[:results].to_h, source: Current.source == "agent" ? "agent" : "person",
        notes: attributes[:notes], evidence_url: attributes[:evidence_url])
      if run.persisted?
        redirect_to qa_check_path(@check), notice: "#{run.passed? ? "Passed" : "Failed"}: #{run.summary}.#{" An issue is open for each failure." if run.failed?}"
      else
        redirect_back fallback_location: qa_check_path(@check), alert: run.errors.full_messages.to_sentence
      end
    end

    def show
      @run = Run.includes(:results, :user, check: :client).find(params[:id])
    end
  end
end
