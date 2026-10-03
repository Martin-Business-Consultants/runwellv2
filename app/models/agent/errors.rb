# The machine-readable half of an agent's error: a stable `code` to branch on, and a `hint`
# saying what to do next. The CLI maps codes to exit statuses (runwell help exit-codes).
module Agent
  module Errors
    CODES = %w[usage not_found ambiguous auth forbidden refused invalid read_only paused rate_limited failed].freeze

    HINTS = {
      "usage" => "Check the inputs: `runwell help %{tool}`, or the tool's input schema.",
      "not_found" => "Check the id or ref. `search` or the matching list_ tool finds it.",
      "ambiguous" => "More than one record matches that name: pick one from candidates and call %{tool} again with its id.",
      "auth" => "Sign in again: the person runs `runwell login` in a terminal.",
      "forbidden" => "This person's role can't do that. `me` lists what it can; ask the person.",
      "refused" => "Runwell refused it as things stand (the summary says why). Change what it depends on, or ask the person.",
      "invalid" => "Fix the fields named in errors and call %{tool} again.",
      "read_only" => "This token is read-only. Ask the person for a token that can make changes.",
      "paused" => "The person paused this connection in Connected apps. Ask them to resume it.",
      "rate_limited" => "Too many calls in a minute. Wait %{retry} seconds, then carry on; batch where a tool allows it.",
      "failed" => "Try once more; if it fails again, tell the person what you were doing."
    }.freeze

    def self.code_for_status(status)
      case status.to_i
      when 400 then "usage"
      when 401 then "auth"
      when 403 then "forbidden"
      when 404 then "not_found"
      when 422 then "invalid"
      when 429 then "rate_limited"
      else "failed"
      end
    end

    def self.hint(code, tool: nil, retry_after: 60) = HINTS.fetch(code, HINTS["failed"]) % { tool: tool || "the tool", retry: retry_after }
  end
end
