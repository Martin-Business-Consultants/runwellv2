json.summary "#{pluralize(@works.size, term(:work).downcase)} (#{@state.humanize.downcase}#{", #{@label}" unless @label == "all"})"
json.works @works, partial: "works/work", as: :work
