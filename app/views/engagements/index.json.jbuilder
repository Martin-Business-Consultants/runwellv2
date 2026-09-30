json.summary "#{pluralize(@engagements.size, term(:engagement).downcase)} (#{@state.humanize.downcase}#{", #{@label}" unless @label == "all"})"
json.engagements @engagements, partial: "engagements/engagement", as: :engagement
