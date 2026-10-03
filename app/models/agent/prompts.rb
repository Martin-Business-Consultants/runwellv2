# Ready-made requests a harness can offer as one-tap starts (MCP prompts): each says, in the
# person's words, what they want and which tools get it. Staff have their set; a client's agent
# its own (Portal::McpController).
module Agent
  module Prompts
    Spec = Data.define(:name, :title, :description, :arguments, :text)

    STAFF = [
      Spec.new("plan_my_day", "Plan my day", "What needs me today, and what to do first.", [],
        ->(_) { "Call `briefing`, then `list_work` for my open work by due date. Tell me, in a short list, what needs me today (questions to answer, requests to triage, anything overdue or blocked) and what to start with. Don't change anything." }),
      Spec.new("standup", "Standup", "What changed across the team since yesterday, by engagement.",
        [ { name: "since", description: "How far back, like 24h or 3d (default 24h)" } ],
        ->(args) { "Call `changes` with since: #{args[:since].presence || "24h"} (and again with after: the cursor while more is true). Summarise by engagement: what moved, what came in, what was sent or decided, who did it. Then list anything blocked or overdue from `briefing`. Keep it short enough to read aloud." }),
      Spec.new("triage_requests", "Triage requests", "Go through open requests and propose what each should become.", [],
        ->(_) { "Call `list_requests` for open requests. For each, read it with `show_request` and propose one of: a new engagement, a change to an engagement's draft, a todo, a commitment, or dismissing it, with why. Ask me before promoting or dismissing anything, one request at a time." }),
      Spec.new("client_update", "Weekly client update", "Draft this week's update for a client, from what happened.",
        [ { name: "client", description: "The client's name", required: true } ],
        ->(args) { "Draft a weekly update for #{args[:client]}. Use `show_client` (id: \"#{args[:client]}\") and `changes` with client_id: \"#{args[:client]}\" and since: 7d. Cover what was delivered, what's in progress, what we need from them, and what's next, in plain language a client reads in a minute. Show me the draft; don't send anything." }),
      Spec.new("catch_up", "Catch me up on an engagement", "Where an engagement stands: agreed, done, in progress, waiting.",
        [ { name: "engagement", description: "Its ref (WO-12) or title", required: true } ],
        ->(args) { "Call `show_engagement` with ref: \"#{args[:engagement]}\". Tell me what was agreed, what's done, what's in progress and with whom, what we're waiting on (commitments), and anything overdue or blocked. Short." })
    ].freeze

    CLIENT = [
      Spec.new("project_status", "Where are things at?", "The state of the work being done for you.", [],
        ->(_) { "Call `portal_engagements`, then `portal_engagement` for each that's active. Tell me in plain language what's done, what's in progress, and anything waiting on me (an agreement to decide, or something they asked for)." }),
      Spec.new("send_a_request", "Ask for something", "Turn what you need into a request they'll triage.",
        [ { name: "what", description: "What you need, in your words", required: true } ],
        ->(args) { "I want to ask them for this: #{args[:what]}. Write it as a request with a short, clear subject and a description of what I need and by when, show me, and send it with `portal_send_request` once I agree." })
    ].freeze

    def self.staff = STAFF.map { build(it) }
    def self.client = CLIENT.map { build(it) }

    def self.build(spec)
      MCP::Prompt.define(name: spec.name, title: spec.title, description: spec.description,
        arguments: spec.arguments.map { MCP::Prompt::Argument.new(**it) }) do |args|
        text = spec.text.call((args || {}).to_h.transform_keys(&:to_sym))
        MCP::Prompt::Result.new(description: spec.description, messages: [ MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(text)) ])
      end
    end
  end
end
