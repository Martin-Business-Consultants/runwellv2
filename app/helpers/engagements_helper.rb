module EngagementsHelper
  # One line under an engagement's state saying what happens next, so the page carries the flow
  # Help describes: build the draft, send it, wait on the client, revise, then do the work.
  def engagement_next_step(engagement)
    case engagement.state
    when "draft" then draft_next_step(engagement)
    when "sent" then sent_next_step(engagement)
    when "changes_requested" then changes_next_step(engagement)
    when "approved" then approved_next_step(engagement)
    when "internal" then internal_next_step(engagement)
    end
  end

  private
    def draft_next_step(engagement)
      draft = engagement.draft_version
      approvers = engagement.client.contacts.active.where(can_approve: true).ordered.map(&:name)

      if draft.nil?
        "Next: start the agreement below, add its #{term(:scope_item, count: 2).downcase}, then send it to the client."
      elsif draft.scope_items.none?
        "Next: add #{term(:scope_item, count: 2).downcase} to the draft below, then send it to the client."
      elsif approvers.empty?
        safe_join([ "Next: nobody at #{engagement.client.name} can approve yet. ",
          link_to("Add a contact who can approve", engagement.client, class: "txt-link"), ", then send the draft." ])
      else
        "Next: send the draft to #{approvers.to_sentence} to approve."
      end
    end

    def sent_next_step(engagement)
      version = engagement.pending_version
      contacts = version.approval_links.map(&:contact).uniq.map(&:name)
      waiting_on = contacts.any? ? contacts.to_sentence : engagement.client.name
      "Waiting on #{waiting_on} since #{l version.sent_at.to_date, format: :long}. Email the link again or record their decision below."
    end

    def changes_next_step(engagement)
      approval = engagement.agreement_versions.last.approval
      who = approval.contact&.name || approval.approver_name.presence || engagement.client.name
      fix = engagement.recurring? ? "a revision" : "a change order"
      "#{who} asked for changes on #{l approval.decided_at.to_date, format: :long}. Start #{fix} below and send it again."
    end

    def internal_next_step(engagement)
      done, open = engagement.todos.partition { it.status == "done" }.map(&:size)
      work = engagement.todos.none? ? "nothing yet, so add it below" : (open.zero? ? "all done" : "#{open} open, #{done} done")
      "Internal: no agreement to send. #{term(:work)}: #{work}."
    end

    def approved_next_step(engagement)
      done, open = engagement.todos.partition { it.status == "done" }.map(&:size)
      work = open.zero? ? "all done" : "#{open} open, #{done} done"
      "Approved #{l engagement.current_version.approval.decided_at.to_date, format: :long}. #{term(:work)}: #{work}. Changes go through a new version."
    end
end
