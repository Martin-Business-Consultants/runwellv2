json.summary "#{@issue.title}: #{@issue.state}#{", found live" if @issue.found_live}"
json.partial! "qa/issues/issue", issue: @issue
