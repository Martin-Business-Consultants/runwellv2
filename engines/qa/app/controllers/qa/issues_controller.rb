# The QA issue log: every defect, where and how it shows, who fixes it, the root cause, and who
# verified the fix. Logged from the quick action tray (QA issue) or opened by a failing test.
module Qa
  class IssuesController < ApplicationController
    allow_staff
    agent_tool :list_qa_issues, on: :index, title: "List QA issues",
      params: { state: %w[open fixed verified all], found: %w[all live caught], assignee: %w[anyone me], client_id: "integer" }
    agent_tool :create_qa_issue, on: :create, title: "Log a QA issue",
      description: "No vague tickets: url (where), steps (how to see it), expected (what should happen, per the source of truth) and actual (what did). record: \"Type:id\" for a Client, Engagement or Todo. found_live: customers could see it. assignee_id: who fixes it.",
      params: { record: "string!", issue: { title: "string!", url: "string", steps: "text!", expected: "text!", actual: "text!", environment: "string", found_live: "boolean", assignee_id: "integer", check_id: "integer" } }
    agent_tool :show_qa_issue, on: :show, title: "Show a QA issue"
    agent_tool :update_qa_issue, on: :update, title: "Change a QA issue",
      params: { issue: { title: "string", url: "string", steps: "text", expected: "text", actual: "text", environment: "string", found_live: "boolean", assignee_id: "integer" } }
    agent_tool :fix_qa_issue, on: :fix, title: "Mark a QA issue fixed, with its root cause",
      description: "Someone else verifies it, or the next passing test of its check does.", params: { root_cause: Issue::ROOT_CAUSES.keys, note: "text" }
    agent_tool :verify_qa_issue, on: :verify, title: "Verify a fixed QA issue", description: "Not by whoever fixed it."
    agent_tool :reopen_qa_issue, on: :reopen, title: "Reopen a QA issue", params: { note: "string" }
    agent_tool :delete_qa_issue, on: :destroy, title: "Delete a QA issue logged by mistake", description: "Only while open."
    require_permission :delete_records, only: :destroy

    before_action :set_issue, except: %i[index create]

    def index
      @view = index_view
      @state = params[:state].presence_in(%w[open fixed verified all]) || "open"
      @found = params[:found].presence_in(%w[all live caught]) || "all"
      @assignee = params[:assignee].presence_in(%w[anyone me]) || "anyone"

      scope = Issue.includes(:client, :engagement, :check, :assignee).recent
      scope = scope.public_send(@state == "verified" ? :verified : @state) unless @state == "all"
      scope = scope.where(found_live: @found == "live") unless @found == "all"
      scope = scope.where(assignee: Current.user) if @assignee == "me"
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      @issues = paginate scope
    end

    def show
    end

    def create
      record = QuickAction.locate(params[:record], QuickAction::RECORD_TYPES) if params[:record].present?
      record = record.try(:engagement) || record.try(:client) unless record.nil? || Issue::RECORD_TYPES.include?(record.class.name)
      issue = Issue.new(issue_params.merge(opened_by: Current.user, source: Current.source || "app"))
      issue.about = record if record
      issue.client ||= issue.check&.client

      if issue.client.nil?
        redirect_back fallback_location: qa_issues_path, alert: "Choose the #{helpers.term(:client).downcase}, #{helpers.term(:engagement).downcase} or #{helpers.term(:work).downcase} it’s about."
      elsif issue.save
        redirect_to qa_issue_path(issue), notice: "Logged: #{issue.title}.#{" #{issue.assignee.display_name} will see it on home." if issue.assignee}"
      else
        redirect_back fallback_location: qa_issues_path, alert: issue.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      return redirect_to(qa_issue_path(@issue), alert: "Only whoever logged it, its assignee, or someone who may manage QA can change it.") unless @issue.fillable_by?(Current.user)

      if @issue.update(issue_params)
        redirect_to qa_issue_path(@issue), notice: "Saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def fix
      return redirect_to(qa_issue_path(@issue), alert: "It’s already marked fixed.") unless @issue.open?
      return redirect_to(qa_issue_path(@issue), alert: "Say what caused it: the root cause is how the same mistake stops happening.") unless params[:root_cause].presence_in(Issue::ROOT_CAUSES.keys)

      @issue.fix!(by: Current.user, root_cause: params[:root_cause], note: params[:note])
      redirect_to qa_issue_path(@issue), notice: "Marked fixed. #{@issue.check ? "The next passing test of #{@issue.check.name} verifies it" : "Someone else verifies it"}."
    end

    def verify
      return redirect_to(qa_issue_path(@issue), alert: "Mark it fixed first, with its root cause.") if @issue.open?
      return redirect_to(qa_issue_path(@issue), alert: "It’s already verified.") if @issue.verified?
      return redirect_to(qa_issue_path(@issue), alert: "Someone other than whoever fixed it verifies the fix.") if @issue.fixed_by == Current.user
      return redirect_to(qa_issue_path(@issue), alert: "Whoever logged it, the check’s owner, or someone who may manage QA verifies it.") unless Attention.verifiable_by?(Current.user, @issue)

      @issue.verify!(by: Current.user)
      redirect_to qa_issue_path(@issue), notice: "Verified."
    end

    def reopen
      return redirect_to(qa_issue_path(@issue), alert: "It’s still open.") if @issue.open?

      @issue.reopen!(note: params[:note])
      redirect_to qa_issue_path(@issue), notice: "Reopened."
    end

    def destroy
      return redirect_to(qa_issue_path(@issue), alert: "Only an open issue can be deleted; a fixed one is part of the record.") unless @issue.open?

      @issue.destroy!
      redirect_to qa_issues_path, notice: "Deleted the issue."
    end

    private
      def set_issue = @issue = Issue.find(params[:id])

      def issue_params
        attributes = params.expect(issue: %i[title url steps expected actual environment found_live assignee_id check_id])
        attributes[:assignee] = ::User.active.people.find_by(id: attributes.delete(:assignee_id)) if attributes.key?(:assignee_id)
        attributes[:check] = Check.find_by(id: attributes.delete(:check_id)) if attributes.key?(:check_id)
        attributes
      end
  end
end
