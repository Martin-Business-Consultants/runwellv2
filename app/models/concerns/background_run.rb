# Something Runwell runs in the background and reports on (an update, a plugin change): running
# until it succeeds or fails, one at a time (current), and settled after the install restarts
# (reconcile, which calls each model's own reconcile!).
module BackgroundRun
  extend ActiveSupport::Concern

  STATUSES = %w[running succeeded failed].freeze

  included do
    validates :status, inclusion: { in: STATUSES }

    scope :running, -> { where(status: "running") }
    scope :failed, -> { where(status: "failed") }
    scope :ordered, -> { order(created_at: :desc) }
  end

  class_methods do
    def current = running.ordered.first
    def reconcile = running.find_each(&:reconcile!)
  end

  def running? = status == "running"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"

  def fail!(message)
    update!(status: "failed", finished_at: Time.current, message: message)
  end
end
