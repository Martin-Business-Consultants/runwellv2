module AccountManagement
  # The standard a lead is held to. The scorecard measures against these, the playbook page
  # prints them, and home warns before each one is missed.
  module Playbook
    AGENDA_AHEAD = 24.hours     # an agenda goes out at least this long before the meeting
    RECAP_WITHIN = 24.hours     # a recap goes out within this long after it
    TOKEN_WARNING = 14.days     # home warns this long before a token expires
    VERIFY_EVERY = 90.days      # an access nobody has checked for this long is stale
    UPDATE_DAY = 5              # the weekly update is due by the end of Friday

    # Percent on time, per measure.
    TARGETS = { agendas: 100, recaps: 100, commitments: 95, updates: 100 }.freeze
  end
end
