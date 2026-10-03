# The kinds of suggestion the in-app AI makes on records (AiSuggestion), each with: the records it
# suits, a strict JSON schema for its answer (every field present, "" when there's nothing), the
# prompt (built from the record as its show tool gives it, so the person's permissions apply), and
# how the person uses it (apply, run with their own permissions through the models' verbs).
module Ai::Suggestions
  Definition = Struct.new(:kind, :label, :types, :fast, :schema, :prompt, :apply, keyword_init: true) do
    def prompt_for(subject, user) = prompt.call(subject, user)
    def applies_to?(subject) = types.include?(subject.class.name)
  end

  class Refused < StandardError; end

  DEFINITIONS = {}

  module_function

  def define(kind, **options) = DEFINITIONS[kind.to_s] = Definition.new(kind: kind.to_s, **options)
  def kinds = DEFINITIONS.keys
  def find(kind) = DEFINITIONS.fetch(kind.to_s)

  # A strict object schema: every property required, nothing else allowed.
  def object(properties) = { type: "object", properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
  def list(item) = { type: "array", items: item }
  def text(description = nil) = { type: "string", description: description }.compact
  def date = { type: "string", description: "YYYY-MM-DD, or \"\" when there's no date" }
  def choice(values, description = nil) = { type: "string", enum: values, description: description }.compact

  # The record as the person's show tool gives it (what an agent over MCP would see).
  def record_json(subject, user)
    name = Ai::Tools::ReadRecord::TYPES[subject.class.name] or return "{}"
    tool = Agent::Catalogue.find(name)
    key = tool.path_parameters.first
    Ai.trim Ai.run_tool(user, tool, { key => subject.is_a?(Engagement) ? subject.ref : subject.id })
  end

  def team(user)
    User.people.active.ordered.includes(:todos).map do |person|
      open = person.todos.reject { it.status == "done" }.size
      "- #{person.display_name} (id #{person.id}, #{person.role}): #{open} open"
    end.join("\n")
  end

  def engagement_by_ref(ref, client: nil)
    scope = client ? client.engagements : Engagement.all
    ref.present? ? scope.find_by(ref: ref.to_s.upcase) : nil
  end

  def parse_date(value) = (Date.parse(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/))
end

Ai::Suggestions.define :triage, label: "Suggest how to triage", types: %w[Request], fast: false,
  schema: Ai::Suggestions.object(
    become: Ai::Suggestions.choice(%w[new_engagement scope work commitment dismiss]),
    engagement_ref: Ai::Suggestions.text("For scope, work or a commitment: the engagement's ref, or \"\""),
    label: Ai::Suggestions.choice(Engagement::LABELS + [ "" ], "For a new engagement: its kind"),
    owner: Ai::Suggestions.choice(%w[us client], "For a commitment: who promises"),
    due_on: Ai::Suggestions.date,
    out_of_scope: { type: "boolean", description: "True when it asks for more than the engagement's agreed scope" },
    reason: Ai::Suggestions.text("One or two sentences: why")
  ),
  prompt: ->(request, user) {
    engagements = request.client ? request.client.engagements.includes(:client, agreement_versions: :approval).map { "#{it.ref} #{it.title} (#{it.state})" }.join("; ") : "none: no client yet"
    <<~TEXT
      Triage this request: should it become a new engagement, scope on an existing engagement's agreement (a change), work on an engagement, a commitment (a dated promise), or be dismissed? Prefer existing engagements when it fits one; say if it's beyond what was agreed.

      The client's engagements: #{engagements}

      The request:
      #{Ai::Suggestions.record_json(request, user)}
    TEXT
  },
  apply: ->(suggestion, _selection, user) {
    request = suggestion.subject
    raise Ai::Suggestions::Refused, "Only people who may triage can use this." unless user.can?(:triage_requests)

    p = suggestion.payload
    engagement = Ai::Suggestions.engagement_by_ref(p["engagement_ref"], client: request.client)
    case p["become"]
    when "new_engagement" then request.promote_to_engagement!(label: p["label"].presence_in(Setting.current.enabled_labels) || Setting.current.enabled_labels.first, actor: user)
    when "scope" then engagement ? request.promote_to_change!(engagement: engagement, actor: user) : raise(Ai::Suggestions::Refused, "Pick the engagement yourself: #{p["engagement_ref"]} isn't one of theirs.")
    when "work" then engagement ? request.promote_to_todo!(engagement: engagement, actor: user, due_on: Ai::Suggestions.parse_date(p["due_on"])) : raise(Ai::Suggestions::Refused, "Pick the engagement yourself.")
    when "commitment" then request.promote_to_commitment!(actor: user, due_on: Ai::Suggestions.parse_date(p["due_on"]) || 1.week.from_now.to_date, owner_kind: p["owner"] == "client" ? "client" : "us", user: (user if p["owner"] != "client"), engagement: engagement)
    when "dismiss" then request.dismiss!(reason: p["reason"].to_s.truncate(250), actor: user)
    end
    "Triaged as suggested."
  }

Ai::Suggestions.define :note_actions, label: "Find promises and work", types: %w[Note], fast: true,
  schema: Ai::Suggestions.object(
    commitments: Ai::Suggestions.list(Ai::Suggestions.object(owner: Ai::Suggestions.choice(%w[us client]), description: Ai::Suggestions.text("What will be done, starting with a verb"), due_on: Ai::Suggestions.date)),
    tasks: Ai::Suggestions.list(Ai::Suggestions.object(title: Ai::Suggestions.text, engagement_ref: Ai::Suggestions.text("The engagement it belongs to, or \"\""), due_on: Ai::Suggestions.date))
  ),
  prompt: ->(note, user) {
    <<~TEXT
      Read this note and list what it commits anyone to. Commitments are promises with a date between us and the client ("Rosa will send the logo by Friday": owner client; "we'll share the draft by the 14th": owner us). Tasks are work for us to do. Only what the note says; nothing invented. Today is #{Date.current}.

      It's on #{note.subject_type} #{note.subject.try(:ref) || note.subject_id}: #{Ai::Suggestions.record_json(note.subject, user).truncate(4_000)}

      The note (#{note.kind}, #{note.occurred_at.to_date}):
      #{ActionView::Base.full_sanitizer.sanitize(note.body).truncate(6_000)}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    note = suggestion.subject
    client = note.subject.is_a?(Client) ? note.subject : note.subject.try(:client)
    engagement = note.subject.is_a?(Engagement) ? note.subject : note.subject.try(:engagement)
    made = 0
    Array(suggestion.payload["commitments"]).each_with_index do |item, index|
      next unless selection.include?("commitments-#{index}") && client

      client.commitments.create!(description: item["description"], owner_kind: item["owner"], user: (user if item["owner"] == "us"),
        due_on: Ai::Suggestions.parse_date(item["due_on"]) || 1.week.from_now.to_date, engagement: engagement, source: "note")
      made += 1
    end
    Array(suggestion.payload["tasks"]).each_with_index do |item, index|
      next unless selection.include?("tasks-#{index}")
      target = Ai::Suggestions.engagement_by_ref(item["engagement_ref"], client: client) || engagement
      next unless target

      target.todos.create!(title: item["title"], due_on: Ai::Suggestions.parse_date(item["due_on"]), created_by: user)
      made += 1
    end
    "Added #{made}."
  }

Ai::Suggestions.define :day, label: "Plan my day", types: %w[User], fast: false,
  schema: Ai::Suggestions.object(
    summary: Ai::Suggestions.text("Two to four sentences on the day ahead"),
    priorities: Ai::Suggestions.list(Ai::Suggestions.object(record: Ai::Suggestions.text("\"Type:id\""), what: Ai::Suggestions.text, why: Ai::Suggestions.text))
  ),
  prompt: ->(user, _) {
    <<~TEXT
      Write #{user.first_name}'s plan for today (#{Date.current.to_fs(:long)}): a short summary of what matters, then up to five priorities in order, each naming its record as "Type:id" with why it comes first. From what needs them now:

      #{Ai.trim(Ai.run_tool(user, Agent::Catalogue.find("briefing"), {}))}
    TEXT
  },
  apply: nil

Ai::Suggestions.define :scope_draft, label: "Draft the scope", types: %w[Engagement], fast: false,
  schema: Ai::Suggestions.object(
    items: Ai::Suggestions.list(Ai::Suggestions.object(description: Ai::Suggestions.text("One deliverable, as the client will read it"), internal_estimate: Ai::Suggestions.text("Rough effort for us, internal, or \"\"")))
  ),
  prompt: ->(engagement, user) {
    requests = engagement.client.requests.where(status: "open").limit(10).map { "- #{it.subject}: #{ActionView::Base.full_sanitizer.sanitize(it.body.to_s).truncate(400)}" }.join("\n")
    <<~TEXT
      Draft the scope items for this #{Setting.current.label_name(engagement.label).downcase}'s agreement: clear deliverables the client can say yes to, in their words, each one thing. Skip what's already on the draft. Five to ten items at most.

      #{Ai::Suggestions.record_json(engagement, user)}

      Their open requests:
      #{requests.presence || "none"}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    engagement = suggestion.subject
    raise Ai::Suggestions::Refused, "This #{Setting.current.term(:engagement).downcase} takes no new scope." if engagement.closed?

    version = engagement.draft_version || engagement.draft_version!(actor: user)
    picked = Array(suggestion.payload["items"]).each_with_index.select { |_, index| selection.include?("items-#{index}") }
    picked.each { |item, _| version.scope_items.create!(description: item["description"].to_s.truncate(250), internal_estimate: item["internal_estimate"].presence, price_cents: 0) }
    "Added #{picked.size} to the draft."
  }

Ai::Suggestions.define :agreement_check, label: "Check before sending", types: %w[Engagement], fast: false,
  schema: Ai::Suggestions.object(
    summary: Ai::Suggestions.text("The summary the client reads: plain, warm, two to four sentences, never internal estimates"),
    issues: Ai::Suggestions.list(Ai::Suggestions.object(item: Ai::Suggestions.text, problem: Ai::Suggestions.text))
  ),
  prompt: ->(engagement, user) {
    version = engagement.draft_version
    items = version ? version.scope_items.map { "- #{it.description} (price #{it.price_cents} cents#{", internal estimate #{it.internal_estimate}" if it.internal_estimate.present?})" }.join("\n") : "no draft"
    <<~TEXT
      Check this draft agreement before it goes to the client. List real problems only: vague or overlapping items, missing prices where others have them, anything the client couldn't say yes to as written. Then write the summary the client will read; never mention internal estimates.

      #{Setting.current.label_name(engagement.label)} #{engagement.ref}: #{engagement.title}
      Current summary: #{version&.summary.presence || "none"}
      Items:
      #{items}
    TEXT
  },
  apply: ->(suggestion, _selection, _user) {
    version = suggestion.subject.draft_version or raise(Ai::Suggestions::Refused, "There's no draft any more.")
    version.update!(summary: suggestion.payload["summary"].to_s.truncate(250))
    "Summary updated."
  }

Ai::Suggestions.define :plan_work, label: "Plan the work", types: %w[ScopeItem], fast: false,
  schema: Ai::Suggestions.object(
    tasks: Ai::Suggestions.list(Ai::Suggestions.object(title: Ai::Suggestions.text, owner_id: { type: [ "integer", "null" ], description: "Who should do it, from the team, or null" }, due_on: Ai::Suggestions.date, why: Ai::Suggestions.text("Why this owner, briefly")))
  ),
  prompt: ->(item, user) {
    <<~TEXT
      Break this agreed scope item into the work that delivers it: three to eight concrete tasks in order, each with the best owner from the team (by role and how much they have open) and a due date if the engagement suggests one. Today is #{Date.current}.

      #{Ai::Suggestions.record_json(item, user)}

      The team:
      #{Ai::Suggestions.team(user)}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    item = suggestion.subject
    engagement = item.agreement_version.engagement
    picked = Array(suggestion.payload["tasks"]).each_with_index.select { |_, index| selection.include?("tasks-#{index}") }
    picked.each do |task, _|
      engagement.todos.create!(title: task["title"].to_s.truncate(250), scope_item: item, owner: User.people.active.find_by(id: task["owner_id"]),
        due_on: Ai::Suggestions.parse_date(task["due_on"]), created_by: user)
    end
    "Added #{picked.size} to #{engagement.ref}."
  }

Ai::Suggestions.define :reminder, label: "Draft a reminder", types: %w[Commitment], fast: true,
  schema: Ai::Suggestions.object(message: Ai::Suggestions.text("The message to send, ready to paste")),
  prompt: ->(commitment, _user) {
    who = commitment.owner_kind == "client" ? "they promised us" : "we promised them"
    <<~TEXT
      Write a short, friendly message about this commitment (#{who}), ready to paste into an email or chat. #{commitment.owner_kind == "client" ? "A gentle nudge: what we need, and why it matters now." : "An honest update: where it stands and, if it will slip, the new date to offer."} No subject line, no placeholders. Today is #{Date.current}.

      #{commitment.owner_name} will #{commitment.description}, by #{commitment.due_on}#{" (overdue)" if commitment.overdue?}. #{Setting.current.term(:client)}: #{commitment.client.name}.#{" #{Setting.current.term(:engagement)}: #{commitment.engagement.ref} #{commitment.engagement.title}." if commitment.engagement}
    TEXT
  },
  apply: nil

Ai::Suggestions.define :client_week, label: "Summarise the week", types: %w[Client], fast: false,
  schema: Ai::Suggestions.object(summary: Ai::Suggestions.text("A short update on the past week and what's next, for us or to send them")),
  prompt: ->(client, user) {
    <<~TEXT
      Summarise the past week with this #{Setting.current.term(:client).downcase} (to #{Date.current}): what moved, what we're waiting on them for, what we've promised, what's next. Five to eight lines, plain, no internal estimates.

      #{Ai::Suggestions.record_json(client, user)}
    TEXT
  },
  apply: ->(suggestion, _selection, user) {
    suggestion.subject.notes.create!(body: suggestion.payload["summary"].to_s, kind: "internal", source: "Runwell AI", author: user)
    "Saved as a note."
  }
