json.summary "#{@meeting.title}, #{@meeting.when_label}: #{@meeting.state.humanize.downcase}; agenda #{account_paper_line(@meeting, :agenda).downcase}; recap #{account_paper_line(@meeting, :recap).downcase}"
json.partial! "account_management/meetings/meeting", meeting: @meeting
json.agenda agent_text(@meeting.agenda)
json.recap agent_text(@meeting.recap)
json.action_items @meeting.commitments.order(:due_on) do |commitment|
  json.merge! agent_ref(commitment)
  json.extract! commitment, :description, :due_on, :resolution
  json.owner commitment.owner
  json.owner_name commitment.owner_name
end
json.recipients(@meeting.recipients.map { { "id" => it.id, "name" => it.name, "email" => it.email } })
