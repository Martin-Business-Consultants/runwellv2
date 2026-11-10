# A task that comes round again (repeat: weekly, every two weeks, monthly, quarterly or yearly):
# "Send the monthly report", due the 3rd. Marking it done makes the next one, due a period after
# this one was (skipping periods already gone, so a late finish doesn't leave it overdue), with the
# same title, description, section, people and client visibility; the repeat moves onto the new
# task, so reopening the old one doesn't make another. Its history says task.repeated.
#
# Only work that's going on repeats: nothing comes round on closed work, for a client that isn't
# active, or when something other than a person marked it done (a client's sunset, status_reason).
module Task::Repeats
  extend ActiveSupport::Concern

  included do
    normalizes :repeat, with: ->(repeat) { repeat.to_s.presence }
    validates :repeat, inclusion: { in: Cadence::KEYS }, allow_nil: true

    after_save :repeat_next!, if: -> { saved_change_to_status?(to: "done") && repeats_now? }
  end

  # The next one, when this save made it (so the answer can bring it onto the page).
  attr_reader :repeated_task

  def repeats? = repeat.present?
  def repeat_name = Cadence.name(repeat)

  # When the next one would be due, if it were done today.
  def next_due_on = repeats? ? Cadence.next_after(due_on || Date.current, repeat) : nil

  # Undo on marking it done (the status toast): back to the status it had. If that made the next
  # one, the next one goes too while nobody has touched it (the repeat moves back here); once it has
  # been changed it stays, and the answer says so.
  def undo_done!(to)
    following = next_made_by_repeat
    update!(status: to)
    return unless following

    if following.untouched_since_repeat?
      following.destroy!
      update_column(:repeat, following.repeat)
      nil
    else
      "The next one stays: it’s been changed since."
    end
  end

  def untouched_since_repeat? = status == "planned" && updated_at <= created_at + 2.seconds && notes.none?

  private
    def next_made_by_repeat
      id = events.where(kind: "task.repeated").order(:occurred_at).last&.payload&.dig("next_task_id")
      Task.find_by(id: id) if id
    end

    def repeats_now?
      repeats? && status_reason.nil? && (work.nil? || work.active?) && (client.nil? || client.status == "active")
    end

    def repeat_next!
      following = @repeated_task = Task.create!(title: title, description: description, work: work, client: client, scope_item: scope_item,
        owner: owner, other_owner_ids: other_owners.map(&:id), client_visible: client_visible, due_on: next_due_on,
        repeat: repeat, source: "app", created_by: Current.user || created_by)
      update_column(:repeat, nil)
      record_event!("task.repeated", payload: { next_task_id: following.id, due_on: following.due_on&.iso8601, repeat: following.repeat })
    end
end
