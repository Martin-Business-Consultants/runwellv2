json.summary "#{pluralize(@issues.size, "issue")} (#{@state}#{", found live" if @found == "live"}#{", before live" if @found == "caught"})"
json.issues @issues, partial: "qa/issues/issue", as: :issue
