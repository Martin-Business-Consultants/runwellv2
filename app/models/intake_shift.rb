# One line of the Intake schedule (Intake > Schedule, IntakeShiftsController): who hears what comes
# into Intake (Task::Intake), from which sources (clients, agents, the team), on which days, and
# how: as it comes in, inside a window of the day (instant), or a summary of everything waiting at
# set times (digest, IntakeMailer#digest). Times are the install's (Setting.zone); a window whose end
# is before its start runs overnight.
#
# With no schedule, a client's request tells every owner and manager straight away (the core's rule,
# Notifier::RequestNotifier) and nothing else notifies. With one, what comes in goes to everyone whose
# window is open and covers its source; anything nobody covers waits (tasks.intake_notified_at nil)
# and goes to whoever's window opens next (IntakeShift.deliver, every minute, IntakeDeliveryJob).
# Accepted or declined meanwhile, it's no longer waiting and nobody is told. Digests don't count as
# telling: they're a look at the whole of Intake.
class IntakeShift < ApplicationRecord
  MODES = { "instant" => "As it comes in", "digest" => "A digest" }.freeze
  SOURCES = %w[clients agents team].freeze
  # Monday first, as people read a week; Ruby's wday numbers.
  DAYS = { 1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 0 => "Sun" }.freeze
  STEP = 30
  # How late a digest may still go out (the server was down at its time).
  DIGEST_GRACE = 1.hour

  belongs_to :user

  scope :ordered, -> { order(:id) }

  before_validation :tidy
  validates :mode, inclusion: { in: MODES.keys }
  validates :days, presence: { message: "needs at least one day" }
  validates :sources, presence: { message: "needs at least one source" }
  validates :digest_minutes, presence: { message: "needs at least one time" }, if: :digest?
  validates :from_minute, :to_minute, inclusion: { in: 0...1440 }
  validate :window_has_length, unless: :digest?
  validate :person_on_the_team

  class << self
    # Every time of day a shift can start, end or send a digest: [["08:30", 510], …].
    def time_options = (0...1440).step(STEP).map { [ clock(it), it ] }
    def clock(minute) = format("%02d:%02d", minute / 60, minute % 60)

    # Tells whoever's on now about what's waiting for them, and sends any digest due. Run every
    # minute and as something comes in; with no schedule there's nothing to do.
    def deliver(now = Time.current)
      shifts = includes(:user).to_a.select { it.user.active? }
      return if shifts.empty?

      open = shifts.select { it.open_at?(now) }
      if open.any?
        Task.intake.where(intake_notified_at: nil).includes(:contact, :client).find_each do |task|
          people = open.select { it.covers?(task) }.map(&:user).uniq
          Notifier::IntakeNotifier.new(task, people).notify if people.any?
        end
      end

      shifts.select { it.digest_due?(now) }.each { it.send_digest(now) }
    end
  end

  def instant? = mode == "instant"
  def digest? = mode == "digest"

  def open_at?(time)
    return false unless instant?

    minute = time.hour * 60 + time.min
    if from_minute < to_minute
      days.include?(time.wday) && minute >= from_minute && minute < to_minute
    elsif minute >= from_minute
      days.include?(time.wday)
    else
      days.include?(time.yesterday.wday) && minute < to_minute
    end
  end

  # Whether a task came from one of its sources.
  def covers?(task) = sources.include?(self.class.source_of(task))

  def self.source_of(task)
    if task.contact_id.present? || task.sender_email.present? then "clients"
    elsif task.made_by_agent? then "agents"
    else "team"
    end
  end

  # The latest digest time today that has passed and hasn't been sent, while it's still fresh.
  def digest_due?(now)
    return false unless digest? && days.include?(now.wday)

    slot = digest_minutes.map { now.beginning_of_day + it.minutes }.select { it <= now }.max
    slot.present? && now - slot < DIGEST_GRACE && (last_digest_at.nil? || last_digest_at < slot) && created_at < slot
  end

  # Everything waiting in Intake from its sources, if anything is.
  def send_digest(now = Time.current)
    update_columns(last_digest_at: now)
    tasks = Task.intake.includes(:contact, :client).order(:intake_at).select { covers?(it) }
    IntakeMailer.digest(self, tasks.map(&:id)).deliver_later if tasks.any?
  end

  def days_label
    return "Every day" if days.size == 7
    return "Weekdays" if days.sort == [ 1, 2, 3, 4, 5 ]
    return "Weekends" if days.sort == [ 0, 6 ]

    DAYS.filter_map { |day, name| name if days.include?(day) }.join(", ")
  end

  def when_label
    if digest?
      "#{days_label}, at #{digest_minutes.map { self.class.clock(it) }.to_sentence}"
    else
      "#{days_label}, #{self.class.clock(from_minute)}–#{self.class.clock(to_minute)}"
    end
  end

  private
    def tidy
      self.days = Array(days).compact_blank.map(&:to_i).select { DAYS.key?(it) }.uniq.sort
      self.sources = Array(sources).compact_blank.map(&:to_s) & SOURCES
      self.digest_minutes = Array(digest_minutes).compact_blank.map(&:to_i).select { it.between?(0, 1439) }.uniq.sort
    end

    def window_has_length
      errors.add(:to_minute, "must differ from the start") if from_minute == to_minute
    end

    def person_on_the_team
      errors.add(:user, "must be someone on the team") unless user&.staff? && !user.agent? && user.active?
    end
end
