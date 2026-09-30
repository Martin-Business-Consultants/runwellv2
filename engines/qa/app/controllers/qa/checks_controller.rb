# A client's checks: adding one (from the usual list for its kind), its page with the source of
# truth and every test, changing it, and archiving it. A check that was ever tested is archived,
# never deleted, so its proof stays.
module Qa
  class ChecksController < ApplicationController
    allow_staff
    require_permission :manage_qa, only: %i[new create]
    agent_tool :create_qa_check, on: :create, title: "Add a QA check to a client",
      description: "One thing we're accountable for: an email, a page, a webhook or a form. kind picks the usual checklist to start from (use_template, default true); add the agreed values with add_qa_expectation. live: it's in production now, so failures count as escapes and the nightly page check runs. every_days: how often it must be tested again.",
      params: { check: { client_id: "integer!", engagement_ref: "string", name: "string!", kind: Check::KINDS, url: "string", live: "boolean", every_days: "integer", owner_id: "integer", instructions: "text" }, use_template: "boolean" },
      next_tools: %i[add_qa_expectation]
    agent_tool :show_qa_check, on: :show, title: "Show a QA check", params: { fact: "integer" },
      description: "Its source of truth (each expectation with its key, rule, expiry and latest result), recent tests, open issues, and the URL the site can report to."
    agent_tool :update_qa_check, on: :update, title: "Change a QA check",
      params: { check: { name: "string", kind: Check::KINDS, url: "string", live: "boolean", every_days: "integer", owner_id: "integer", engagement_ref: "string", instructions: "text" } }
    agent_tool :archive_qa_check, on: :destroy, title: "Archive a QA check", description: "Its tests and issues stay. A check never tested is deleted."

    before_action :set_check, only: %i[show edit update destroy]
    before_action :require_check_editor, only: %i[edit update destroy]

    def new
      @check = Check.new(client: ::Client.find_by(id: params[:client_id]), kind: params[:kind].presence_in(Check::KINDS) || "email", owner: Current.user)
    end

    def create
      @check = Check.new(check_params.merge(created_by: Current.user))
      @check.owner ||= Current.user
      if @check.save
        @check.apply_template! unless params[:use_template].to_s == "false" || params[:use_template].to_s == "0"
        @check.client.record_event!("qa.check_added", payload: { check: @check.name })
        redirect_to qa_check_path(@check), notice: "Added #{@check.name}. Now fill in what’s agreed: each expected value is the source of truth it’s tested against."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @runs = @check.runs.recent.includes(:user, :results).limit(20)
      @issues = @check.issues.unverified.includes(:assignee).recent
      # The fact whose sheet is open (?fact=), from a click on its row.
      @fact = @check.expectations.find_by(id: params[:fact]) if params[:fact].present?
    end

    def edit
    end

    def update
      if @check.update(check_params)
        redirect_to qa_check_path(@check), notice: "Saved #{@check.name}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @check.runs.exists?
        @check.archive!
        redirect_to client_path(@check.client), notice: "Archived #{@check.name}. Its tests and issues are kept."
      else
        @check.destroy!
        redirect_to client_path(@check.client), notice: "Deleted #{@check.name}."
      end
    end

    private
      def check_params
        attributes = params.expect(check: %i[client_id engagement_ref name kind url live every_days owner_id instructions])
        if attributes.key?(:engagement_ref)
          ref = attributes.delete(:engagement_ref)
          attributes[:engagement] = ref.present? ? ::Engagement.find_by_ref!(ref) : nil
        end
        attributes[:owner] = ::User.active.people.find_by(id: attributes.delete(:owner_id)) if attributes.key?(:owner_id)
        attributes[:client] = ::Client.find(attributes.delete(:client_id)) if attributes.key?(:client_id) && action_name == "create"
        attributes.except(:client_id)
      end
  end
end
