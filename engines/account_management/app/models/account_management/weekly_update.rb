module AccountManagement
  # A lead's written report for the week, due by the end of Friday: per client, what happened,
  # what shipped, what's next, blockers and risks. Drafted from the week's records, finished by
  # the person, and final once sent.
  class WeeklyUpdate < ::ApplicationRecord
    include ::Eventful

    belongs_to :user, class_name: "::User"

    validates :week_of, presence: true, uniqueness: { scope: :user_id, message: "already has an update" }
    validates :body, presence: { message: "can’t be blank: say how each client’s week went" }, if: :sent?
    validate :week_starts_on_monday
    before_update { raise ActiveRecord::ReadOnlyRecord, "a sent update is final" if sent_at_was }

    scope :sent, -> { where.not(sent_at: nil) }
    scope :recent, -> { order(week_of: :desc) }

    def self.week_of(date = Date.current) = date.beginning_of_week(:monday)

    # People who lead a client owe one every week.
    def self.owed_by?(user) = Lead.exists?(user: user)

    def sent? = sent_at.present?
    def due_at = (week_of + (Playbook::UPDATE_DAY - 1)).in_time_zone.end_of_day
    def on_time? = sent? && sent_at <= due_at
    def late? = sent? ? sent_at > due_at : Time.current > due_at
    def label = "Week of #{week_of.to_fs(:long)}"

    def send!(actor: Current.user, source: Current.source)
      raise ArgumentError, "It’s already sent." if sent?

      transaction do
        self.sent_at = Time.current
        save!
        record_event!("weekly_update.sent", actor: actor, source: source || "app", payload: { on_time: on_time? })
      end
    end

    # A first draft from what the records say, for the lead to correct and finish.
    def draft_body = Draft.new(user, week_of).to_html

    private
      def week_starts_on_monday
        errors.add(:week_of, "must be a Monday") if week_of && !week_of.monday?
      end
  end
end
