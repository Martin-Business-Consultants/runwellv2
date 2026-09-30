class AgreementVersionsController < ApplicationController
  allow_staff
  require_permission :send_agreements, only: %i[send_out issue_link record_decision]
  agent_tool :create_agreement_version, on: :create, title: "Start a draft agreement version",
    description: "A new draft on an engagement: the initial agreement, a change order, a revision or an add-on. Add scope with add_scope_item, then send_agreement.",
    params: { kind: AgreementVersion::KINDS, summary: "string", reason: "string" }, next_tools: %i[add_scope_item send_agreement]
  agent_tool :update_agreement_version, on: :update, title: "Change a draft agreement version",
    params: { agreement_version: { summary: "string", reason: "string", cadence: AgreementVersion::CADENCES, amount_cents: "integer" } }
  agent_tool :discard_draft, on: :destroy, title: "Discard a draft agreement version",
    description: "Only drafts: a sent version is frozen forever."
  agent_tool :send_agreement, on: :send_out, title: "Send an agreement version to the client",
    description: "Freezes the draft (snapshotted and hashed; it can never change again). With contact_id, emails that contact a signed approval link; without, mark it sent and record their decision later with record_decision.",
    params: { contact_id: "integer" }, confirm: "It freezes this version for good and, with a contact, emails them an approval link."
  agent_tool :email_approval_link, on: :issue_link, title: "Email an approval link",
    params: { contact_id: "integer!" }, confirm: "It emails the contact a signed link to approve or ask for changes."
  agent_tool :record_decision, on: :record_decision, title: "Record the client’s decision",
    description: "For a decision that came by email, call or meeting. Say where it came from: the evidence is kept with the approval. Approving creates the work (one todo per scope item).",
    params: { decision: Approval::DECISIONS, contact_id: "integer", approver_name: "string", evidence: "string!", comment: "text" }

  before_action :set_version, except: :create

  def create
    engagement = Engagement.find_by_ref!(params[:engagement_ref])
    version = engagement.draft_version!(actor: current_user, kind: params[:kind].presence,
                                        summary: params[:summary].presence, reason: params[:reason].presence)
    redirect_to engagement, notice: "#{version.label} drafted."
  rescue ArgumentError => e
    redirect_to engagement, alert: e.message
  end

  def update
    if @version.update(version_params)
      redirect_to @version.engagement, notice: "Draft updated."
    else
      redirect_to @version.engagement, alert: @version.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::ReadOnlyRecord
    redirect_to @version.engagement, alert: "#{@version.label} has been sent and can no longer change."
  end

  def destroy
    if @version.destroy
      redirect_to @version.engagement, notice: "Draft discarded."
    else
      redirect_to @version.engagement, alert: @version.errors.full_messages.to_sentence
    end
  end

  # Freeze the draft and, if a contact was chosen, email them an approval link.
  def send_out
    @version.send!(actor: current_user)
    if (contact = @version.engagement.client.contacts.active.find_by(id: params[:contact_id]))
      email_link_to(contact)
      redirect_to @version.engagement, notice: "#{@version.label} sent to #{contact.name}."
    else
      redirect_to @version.engagement, notice: "#{@version.label} marked as sent."
    end
  rescue ArgumentError => e
    redirect_to @version.engagement, alert: e.message
  end

  def issue_link
    contact = @version.engagement.client.contacts.active.find(params[:contact_id])
    email_link_to(contact)
    redirect_to @version.engagement, notice: "Approval link emailed to #{contact.name}."
  end

  # A person records what the client decided, with evidence.
  def record_decision
    contact = @version.engagement.client.contacts.find_by(id: params[:contact_id])
    @version.decide!(decision: params.require(:decision), method: "recorded", contact: contact,
                     approver_name: params[:approver_name].presence, comment: params[:comment].presence,
                     evidence: params[:evidence].presence, recorded_by: current_user)
    redirect_to @version.engagement, notice: "Decision recorded."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @version.engagement, alert: e.message
  end

  private

  def set_version = @version = AgreementVersion.find(params[:id])

  def version_params
    params.expect(agreement_version: %i[summary reason cadence amount_cents])
  end

  def email_link_to(contact)
    link = @version.issue_link!(contact)
    AgreementMailer.with(link: link).sent.deliver_later
    @version.record_event!("agreement.emailed", payload: { to: contact.email })
  end
end
