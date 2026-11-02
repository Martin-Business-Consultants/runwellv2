# What needs this person now: the home page and the briefing tool. Their own open work by when it's
# due (overdue, today, the week after, and what they're in the middle of with no date that close),
# then what's waiting on them (work in review they lead, blocked work they're on, mentions they
# haven't read) and whatever plugins add.
class Briefing
  # items is the first `limit` of the section; count is all of them. group: :work (Your work) or
  # :waiting (Waiting on you).
  Section = Struct.new(:key, :title, :items, :count, :group, :partial, keyword_init: true)

  WORK = %w[overdue today week in_progress].freeze

  def initialize(user, limit: 25)
    @user = user.person
    @limit = limit
  end

  def sections
    @sections ||= [
      section("overdue", "Overdue", :work, work(mine.overdue.order(:due_on))),
      section("today", "Due today", :work, work(mine.due_today.order(:position))),
      section("week", "This week", :work, work(mine.due_this_week.order(:due_on))),
      section("in_progress", "In progress", :work, work(mine.where(status: "in_progress").where("due_on IS NULL OR due_on > ?", Date.current + 7).order(:updated_at))),
      section("review", "In review, yours to check", :waiting, work(Todo.where(status: "in_review", owner_id: @user.id).order(:updated_at))),
      section("blocked", "Blocked", :waiting, work(Todo.where(status: "blocked").assigned_to(@user).order(:updated_at))),
      section("mentions", "Mentions", :waiting, @user.notifications.unread.preloaded.order(created_at: :desc))
    ].concat(plugin_sections).reject { it.count.zero? }
  end

  def work_sections = sections.select { it.group == :work }
  def waiting_sections = sections.select { it.group == :waiting }
  def empty? = sections.empty?
  def count(key) = sections.find { it.key == key }&.count.to_i

  private
    def mine = Todo.open.assigned_to(@user)

    # The first rows, and a count only when there are more: a large install has hundreds overdue.
    def section(key, title, group, scope)
      items = scope.limit(@limit).to_a
      Section.new(key: key, title: title, group: group, items: items, count: items.size < @limit ? items.size : scope.count)
    end

    # A plugin's items are whatever its lambda returns (a relation or an array), so they load whole.
    def plugin_sections
      Runwell::Plugins.enabled_briefings.map do |key, briefing|
        items = briefing.items.call(@user).to_a
        Section.new(key: key.to_s, title: briefing.title, group: :waiting, partial: briefing.partial, items: items.first(@limit), count: items.size)
      end
    end

    # Work with what its row (and its JSON for agents) reads.
    def work(scope) = scope.includes(:engagement, :client, :contact, :owner, :scope_item, :custom_values, assignments: :user)
end
