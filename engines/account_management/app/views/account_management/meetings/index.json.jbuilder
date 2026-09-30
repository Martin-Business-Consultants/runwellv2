json.summary "#{pluralize(@meetings.size, "meeting")} (#{@state})"
json.meetings @meetings, partial: "account_management/meetings/meeting", as: :meeting
