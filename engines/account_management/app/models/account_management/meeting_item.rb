module AccountManagement
  # An action item from a meeting: the core commitment it made, kept with the meeting it came from.
  class MeetingItem < ::ApplicationRecord
    belongs_to :meeting
    belongs_to :commitment, class_name: "::Commitment"
  end
end
