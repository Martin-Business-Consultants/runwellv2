# What needs a human right now. This is the home page.
class Briefing
  Section = Struct.new(:key, :title, :items, :partial, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def sections
    [
      Section.new(key: "questions", title: "Questions for you", items: Question.unanswered.where(user: @user).ordered.to_a),
      Section.new(key: "requests", title: "Requests to triage", items: Request.open.ordered.to_a),
      Section.new(key: "awaiting_client", title: "Waiting on a client", items: awaiting_client),
      Section.new(key: "drafts", title: "Drafts ready to send", items: drafts_ready),
      Section.new(key: "overdue_commitments", title: "Overdue commitments", items: Commitment.overdue.ordered.includes(:client, :engagement).to_a),
      Section.new(key: "due_soon", title: "Due this week", items: Commitment.due_soon.ordered.includes(:client, :engagement).to_a),
      Section.new(key: "review", title: "Ready for review", items: Todo.where(status: "in_review").order(:updated_at).includes(:engagement, :owner).to_a),
      Section.new(key: "blocked", title: "Blocked work", items: Todo.where(status: "blocked").includes(:engagement).to_a),
      Section.new(key: "overdue_todos", title: "Overdue work", items: Todo.overdue.includes(:engagement).to_a)
    ].concat(plugin_sections).reject { |s| s.items.empty? }
  end

  def counts = sections.to_h { |s| [ s.key, s.items.size ] }

  private

  def plugin_sections
    Runwell::Plugins.enabled_briefings.map do |key, briefing|
      Section.new(key: key.to_s, title: briefing.title, partial: briefing.partial, items: briefing.items.call(@user).to_a)
    end
  end

  def awaiting_client
    AgreementVersion.where.not(sent_at: nil).where(superseded_by_id: nil).left_joins(:approval)
                    .where(approvals: { id: nil }).includes(engagement: :client).order(:sent_at).to_a
  end

  def drafts_ready
    AgreementVersion.where(sent_at: nil).joins(:scope_items).distinct.includes(engagement: :client).to_a
  end
end
