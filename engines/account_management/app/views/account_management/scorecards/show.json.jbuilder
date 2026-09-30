json.summary "#{@user.display_name}, last #{@scorecard.days} days: " + @scorecard.measures.map { "#{it.label.downcase} #{account_percent it.percent} (target #{it.target}%)" }.join("; ")
json.partial! "account_management/scorecards/scorecard", scorecard: @scorecard
json.misses do
  @scorecard.measures.each do |measure|
    json.set! measure.key, measure.misses.map { |miss|
      case miss
      when AccountManagement::Meeting then agent_ref(miss).merge("title" => miss.title, "starts_at" => miss.starts_at, "client" => miss.client.name)
      when AccountManagement::WeeklyUpdate then { "week_of" => miss.week_of, "sent_at" => miss.sent_at, "due_at" => miss.due_at }
      else agent_ref(miss).merge("description" => miss.description, "due_on" => miss.due_on, "resolution" => miss.resolution, "resolved_at" => miss.resolved_at, "client" => miss.client.name)
      end
    }
  end
end
json.accesses_needing_attention @scorecard.accesses_needing_attention, partial: "account_management/accesses/access", as: :access
