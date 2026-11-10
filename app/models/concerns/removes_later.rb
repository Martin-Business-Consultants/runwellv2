# A record that can be removed with Undo (PendingRemoval): removing it in the browser waits out the
# window before it goes, so a slip of the keys costs nothing. remove_later! starts the window and
# answers its batch, for the Undo button; removal_pending? says whether it's waiting.
module RemovesLater
  extend ActiveSupport::Concern

  included do
    has_one :pending_removal, as: :record, dependent: :delete
  end

  class_methods do
    def remove_later!(records, by: Current.user) = PendingRemoval.start(records, by: by)
  end

  def remove_later!(by: Current.user) = self.class.remove_later!([ self ], by: by)
  def removal_pending? = PendingRemoval.exists?(record: self)
end
