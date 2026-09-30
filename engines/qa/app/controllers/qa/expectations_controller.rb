# A check's source of truth, one agreed fact at a time. Changing a value is recorded on the
# client's history, and the check has to be tested again.
module Qa
  class ExpectationsController < ApplicationController
    allow_staff
    agent_tool :add_qa_expectation, on: :create, title: "Add an agreed value (or a step) to a QA check",
      description: "label: what it is (\"From address\"); its key is made from it and fixed. expected: the agreed value; leave it blank for a step to tick off (\"every link clicked\"). match: is (exact; spacing, case and phone formatting ignored), list (addresses in any order, comma separated), includes (the check's page must show it), excludes (the page must never show it, e.g. another market's phone number). expires_on: when a promo or offer ends, so home warns before it does.",
      params: { expectation: { label: "string!", expected: "string", match: Matcher::MATCHES.keys, expires_on: "date", note: "string", key: "string" } }
    agent_tool :update_qa_expectation, on: :update, title: "Change an agreed value on a QA check",
      description: "Recorded on the client's history; every earlier pass stops counting until it's tested again.",
      params: { expectation: { label: "string", expected: "string", match: Matcher::MATCHES.keys, expires_on: "date", note: "string" } }
    agent_tool :remove_qa_expectation, on: :destroy, title: "Remove an agreed value from a QA check"

    before_action :set_check, :require_check_editor
    before_action :set_expectation, only: %i[edit update destroy]

    def create
      expectation = @check.expectations.new(params.expect(expectation: %i[label expected match expires_on note key]))
      expectation.position = (@check.expectations.maximum(:position) || -1) + 1
      if expectation.save
        @check.request_retest!
        redirect_back fallback_location: qa_check_path(@check), notice: "Added #{expectation.label} (key #{expectation.key})."
      else
        redirect_back fallback_location: qa_check_path(@check), alert: expectation.errors.full_messages.to_sentence
      end
    end

    # A page of its own: the fact's fields, with its history beside them.
    def edit
      @results = @expectation.results.includes(run: :user).order(id: :desc).limit(10)
    end

    # Back to the check with the fact's sheet open, so what changed is in view.
    def update
      if @expectation.update(params.expect(expectation: %i[label expected match expires_on note]))
        redirect_to qa_check_path(@check, fact: @expectation.id), notice: "Saved #{@expectation.label}."
      elsif params[:from_edit]
        @results = @expectation.results.includes(run: :user).order(id: :desc).limit(10)
        render :edit, status: :unprocessable_entity
      else
        redirect_back fallback_location: qa_check_path(@check), alert: @expectation.errors.full_messages.to_sentence
      end
    end

    def destroy
      @expectation.destroy!
      @check.client.record_event!("qa.source_of_truth_changed", payload: { check: @check.name, fact: @expectation.label, from: @expectation.expected.to_s.truncate(120), to: "(removed)" })
      redirect_to qa_check_path(@check), notice: "Removed #{@expectation.label}."
    end

    private
      def set_expectation = @expectation = @check.expectations.find(params[:id])
  end
end
