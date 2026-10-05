# The personal half of home, around the briefing (what needs a human): the day and a greeting, what's
# due today, what's coming up for this person, their engagements with how each is going, what the
# team is doing, and the latest notes. Each part is a few rows from one or two queries, whatever the
# install's size.
class Briefing::Home
  COMING_UP_DAYS = 7
  SHOWN = 6

  Engagement = Struct.new(:record, :state, :open, :done, :total, :health, keyword_init: true)
  Person = Struct.new(:user, :doing, keyword_init: true)

  def initialize(user)
    @user = user.person
  end

  def greeting
    hour = Time.current.hour
    part = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
    "Good #{part}, #{@user.display_name.split.first}."
  end

  # What's due today: this person's work, and every open promise (ours or the client's).
  def due_today_work = my_open_work.where(due_on: Date.current).count
  def due_today_promises = Commitment.open.where(due_on: Date.current).count

  # This person's open work and our promises they hold, due within the week (late ones too), soonest first.
  def coming_up
    @coming_up ||= begin
      horizon = Date.current + COMING_UP_DAYS
      work = my_open_work.where(due_on: ..horizon).includes(:engagement).order(:due_on).limit(SHOWN).to_a
      promises = Commitment.open.where(user: @user, owner_kind: "us", due_on: ..horizon).includes(:client, :engagement).ordered.limit(SHOWN).to_a
      (work + promises).sort_by(&:due_on).first(SHOWN)
    end
  end

  # Open engagements this person has work on (or, with none, the latest open ones), with their work
  # done of total and how they're going: behind (late work or a late promise of ours), waiting on the
  # client (sent, or changes asked for), a draft, or on track. Derived, never typed in.
  def engagements
    @engagements ||= begin
      mine = ::Engagement.open.where(id: Todo.where(owner: @user).select(:engagement_id))
      scope = mine.exists? ? mine : ::Engagement.open
      records = scope.joins(::Engagement::STATE_JOINS).select("engagements.*", "(#{::Engagement::STATE_SQL}) AS derived_state")
                     .includes(:client).order(updated_at: :desc).limit(SHOWN).to_a
      ids = records.map(&:id)
      counts = Todo.where(engagement_id: ids).group(:engagement_id, Arel.sql("status = 'done'")).count
      late = (Todo.overdue.where(engagement_id: ids).distinct.pluck(:engagement_id) +
              Commitment.overdue.where(engagement_id: ids, owner_kind: "us").distinct.pluck(:engagement_id)).to_set

      records.map do |record|
        done = counts[[ record.id, 1 ]].to_i + counts[[ record.id, true ]].to_i
        open = counts[[ record.id, 0 ]].to_i + counts[[ record.id, false ]].to_i
        Engagement.new(record: record, state: record.derived_state, open: open, done: done, total: open + done, health: health(record, late))
      end
    end
  end

  # People with work in progress, and the first few things each is doing.
  def team
    @team ||= Todo.where(status: "in_progress").where.not(owner_id: nil).includes(:owner, :engagement).order(:updated_at)
                  .group_by(&:owner).filter_map { |user, todos| Person.new(user: user, doing: todos.first(2)) if user.active? }
                  .sort_by { it.user.display_name }
  end

  # The latest notes by others, on anything.
  def discussion
    @discussion ||= Note.where.not(author_id: @user.id).recent.includes(:author, :subject).limit(4).to_a
  end

  private
    def my_open_work = Todo.open.where(owner: @user)

    def health(record, late)
      if late.include?(record.id) then "Behind"
      elsif record.derived_state.in?(%w[sent changes_requested]) then "Waiting"
      elsif record.derived_state == "draft" then "Draft"
      else "On track"
      end
    end
end
