# A record removed in the browser, waiting out its Undo window (WINDOW): the removal goes through
# when it comes due (PendingRemovalJob), unless someone undoes it first, which deletes this row and
# leaves the record as it was. Removals made together (a bulk delete) share a batch, so one Undo
# puts them all back. The record isn't touched meanwhile; agents and plain posts remove at once
# and never come here. Kept out of exports: it's bookkeeping for seconds, not data (Export).
class PendingRemoval < ApplicationRecord
  WINDOW = 8.seconds

  belongs_to :record, polymorphic: true
  belongs_to :user, optional: true

  scope :due, -> { where(created_at: ..WINDOW.ago) }

  # Starts the window for records (RemovesLater#remove_later!): their batch, for Undo.
  def self.start(records, by:)
    batch = SecureRandom.base58(16)
    transaction do
      records.each { |record| find_or_initialize_by(record: record).update!(batch: batch, user: by) }
    end
    PendingRemovalJob.set(wait: WINDOW).perform_later(batch)
    batch
  end

  # The batch's records go, those not undone. Each is destroyed as if removed at once.
  def self.carry_out(batch)
    where(batch: batch).includes(:record).find_each do |removal|
      removal.record&.destroy
      removal.destroy
    end
  end

  # Puts a batch back: how many records it saved (0 once the window has passed).
  def self.undo(batch) = where(batch: batch).delete_all

  # Anything past due that a job never reached (a development server restarted, say).
  def self.sweep = due.distinct.pluck(:batch).each { carry_out(it) }
end
