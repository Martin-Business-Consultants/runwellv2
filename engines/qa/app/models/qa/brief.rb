module Qa
  # The part of an agent's brief for a todo (the AI button, brief_work) that says what must be
  # right: the checks gated on this work first, then the rest of the client's live checks, each
  # with its source of truth. An agent building an email should know the From address before it
  # guesses one.
  module Brief
    def self.call(todo, base_url)
      client = todo.engagement.client
      gated = todo.qa_gates.includes(check: :expectations).map(&:check)
      others = Check.active.live.where(client: client).where.not(id: gated.map(&:id)).includes(:expectations).ordered.to_a
      return if gated.empty? && others.empty?

      lines = [ "## QA: what must be right", "" ]
      if gated.any?
        lines << "This work can't be marked done until these checks pass, tested by someone other than its owner:" << ""
        gated.each { lines.concat(check_lines(it)) }
      end
      if others.any?
        lines << "#{client.name}'s live checks (the source of truth; don't change these values without asking):" << ""
        others.each { lines.concat(check_lines(it)) }
      end
      lines << "Report a test with the `record_qa_test` tool (check_id, and run.results keyed as above: { actual: \"what you saw\" } or { verdict: \"pass\" }). " \
        "Log a defect with `create_qa_issue` (url, steps, expected, actual). Work on it at #{base_url}/qa."
      lines.join("\n")
    end

    def self.check_lines(check)
      [ "### #{check.name} (#{check.kind}#{", #{check.url}" if check.url})", "" ] +
        check.expectations.map { |it| "- `#{it.key}`: #{it.rule}#{" (until #{it.expires_on})" if it.expires_on}" } + [ "" ]
    end
  end
end
