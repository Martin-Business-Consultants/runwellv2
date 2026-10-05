# What needs a human right now. This is the home page.
class Briefing
  # items is the first `limit` of the section (what home and the briefing tool show); count is all.
  Section = Struct.new(:key, :title, :items, :count, :partial, keyword_init: true)

  def initialize(user, limit: 25)
    @user = user
    @limit = limit
  end

  def sections
    [
      section("questions", "Questions for you", Question.unanswered.where(user: @user).ordered.includes(:subject)),
      section("requests", "Requests to triage", Request.open.ordered.includes(:contact, :client)),
      section("awaiting_client", "Waiting on a client", awaiting_client),
      section("drafts", "Drafts ready to send", drafts_ready),
      section("waiting_on_them", "Waiting on them", due_commitments.where(owner_kind: "client")),
      section("you_promised", "You promised", due_commitments.where(owner_kind: "us")),
      section("review", "Ready for review", Todo.where(status: "in_review").order(:updated_at).includes(:engagement, :owner)),
      section("blocked", "Blocked work", Todo.where(status: "blocked").includes(:engagement, :owner)),
      section("overdue_todos", "Overdue work", Todo.overdue.includes(:engagement, :owner))
    ].concat(plugin_sections).reject { |s| s.count.zero? }
  end

  def counts = sections.to_h { |s| [ s.key, s.count ] }

  private

  # The first few rows, and a count only when there are more: a large install has hundreds
  # overdue, and home shows eight.
  def section(key, title, scope)
    items = scope.limit(@limit).to_a
    Section.new(key: key, title: title, items: items, count: items.size < @limit ? items.size : scope.count)
  end

  # A plugin's items are whatever its lambda returns (a relation or an array), so they load whole.
  def plugin_sections
    Runwell::Plugins.enabled_briefings.map do |key, briefing|
      items = briefing.items.call(@user).to_a
      Section.new(key: key.to_s, title: briefing.title, partial: briefing.partial, items: items.first(@limit), count: items.size)
    end
  end

  # Open commitments that are late or due within the week, both lanes.
  def due_commitments
    Commitment.open.where(due_on: ..(Date.current + 7)).ordered.includes(:client, :engagement, :user, :contact)
  end

  def awaiting_client
    AgreementVersion.where.not(sent_at: nil).where(superseded_by_id: nil).left_joins(:approval)
                    .where(approvals: { id: nil }).joins(engagement: :client).where(clients: { internal: false })
                    .includes(:approval, { scope_items: :todos }, engagement: :client).order(:sent_at)
  end

  def drafts_ready
    # An internal project's draft is a plan, never sent.
    AgreementVersion.where(sent_at: nil).where(id: ScopeItem.select(:agreement_version_id)).joins(engagement: :client)
                    .where(clients: { internal: false }).includes(:approval, { scope_items: :todos }, engagement: :client)
  end
end
