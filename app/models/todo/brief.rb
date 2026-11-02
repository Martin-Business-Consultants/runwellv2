# Everything a local AI needs to do one piece of work and report back, as Markdown: what the
# work is and where it sits, the section it belongs to, what's been said, what else is due, how to
# update Runwell with the `runwell` command (or MCP), and whatever plugins add (the Code plugin
# adds repositories and a branch). Copied by the AI button on a todo, and served to agents by
# the brief_work tool. Staff only: it includes internal notes.
class Todo::Brief
  attr_reader :todo, :base_url, :person

  def initialize(todo, base_url:, person:)
    @todo = todo
    @base_url = base_url.to_s.chomp("/")
    @person = person&.person
  end

  def to_s = sections.compact.join("\n\n") + "\n"

  def summary = "Brief for #{todo.title} (Todo:#{todo.id})"

  private
    def engagement = todo.engagement
    def record = "Todo:#{todo.id}"
    def plain(html) = html.present? ? ActionText::Content.new(html.to_s).to_plain_text.strip : nil

    def sections
      [ heading, the_work, agreed_scope, notes, due_alongside, *plugin_sections, working_with_runwell, rules ]
    end

    def heading
      lines = [ "# #{todo.title}", "",
        "Runwell work item #{record}: #{base_url}/work/#{todo.id}",
        "Client: #{todo.client&.name || "none matched yet"}",
        ("#{Setting.current.label_name(engagement.label)}: #{engagement.ref} #{engagement.title}" if engagement),
        ("Requested by: #{todo.requester_name} (#{todo.source})" if todo.requester_name.present?),
        ("#{Setting.current.term(:scope_item)}: #{todo.scope_item.description}" if todo.scope_item),
        "Status: #{todo.status.humanize}" + (todo.owner ? " · Lead: #{todo.owner.display_name}#{" · Also on it: #{todo.other_owners.map(&:display_name).to_sentence}" if todo.other_owners.any?}" : " · Unassigned") + (todo.due_on ? " · Due: #{todo.due_on.iso8601}" : "") ]
      lines.compact.join("\n")
    end

    def the_work
      text = plain(todo.description)
      "## The work\n\n#{text.presence || "(No description. Read the notes below, and ask if it's unclear.)"}"
    end

    # The engagement's sections, so the work is read against the rest of what it delivers.
    def agreed_scope
      return unless engagement

      sections = engagement.scope_items.map { "- #{it.description}#{" (this one)" if it.id == todo.scope_item_id}" }
      return if sections.empty?

      "## #{Setting.current.term(:scope_item, count: 2)} of #{engagement.ref}\n\n#{sections.join("\n")}"
    end

    def notes
      recent = todo.notes.recent.includes(:author).limit(5).to_a
      return if recent.empty?

      "## Recent notes (newest first)\n\n" + recent.map { |n|
        "- #{n.occurred_at.to_date.iso8601} #{n.author&.display_name || "someone"} (#{n.kind}): #{plain(n.body).to_s.squish.truncate(400)}"
      }.join("\n")
    end

    # Other open work with a date alongside this one (on its engagement, else its client): what else
    # has been promised.
    def due_alongside
      home = engagement || todo.client or return
      open = home.todos.open.where.not(id: todo.id).where.not(due_on: nil).includes(:owner).order(:due_on).limit(10).to_a
      return if open.empty?

      "## Other dated work on #{engagement ? engagement.ref : home.name}\n\n" +
        open.map { "- #{it.title} · #{it.owner&.display_name || "unassigned"} · due #{it.due_on.iso8601}" }.join("\n")
    end

    def plugin_sections
      Runwell::Plugins.enabled_agent_briefs.values.filter_map do |builder|
        builder.call(todo, base_url)&.strip.presence
      rescue => error
        Rails.error.report(error, context: { todo: todo.id })
        nil
      end
    end

    def working_with_runwell
      agent = person&.agent&.display_name || "your agent"
      <<~MD.strip
        ## Working with Runwell

        You act as #{agent}: everything you do is recorded as #{agent}, with the app's name, and has exactly #{person&.display_name || "your person"}'s permissions.

        Sign in once with the `runwell` command (or connect an MCP client to #{base_url}/mcp):

        ```sh
        curl -fsSL #{base_url}/install/cli | sh    # if you don't have it yet
        runwell login #{base_url}
        ```

        Then, as you work:

        ```sh
        runwell show_work --id #{todo.id}                                  # the item, fresh
        runwell update_work --id #{todo.id} --todo.status in_progress      # when you start
        runwell add_note --record #{record} --note.body "What you did, found or decided"
        runwell update_work --id #{todo.id} --todo.status blocked          # stuck: add a note saying why
        runwell update_work --id #{todo.id} --todo.status in_review        # finished: a person checks it and marks it done
        ```

        `runwell tools` lists everything you can do; `runwell help <tool>` explains one.
      MD
    end

    def rules
      <<~MD.strip
        ## Ground rules

        - Stay within the agreed scope. If the work needs more than was agreed, stop and leave a note saying so rather than doing it.
        - Leave a note when you start, when you make a decision, and when you finish, so a person can follow what happened.
        - When you're finished, set the status to in_review, not done: a person checks the work and marks it done.
        - Anything that reaches the client (sending, emailing, making something visible to them) will ask for confirmation. Don't confirm it on a person's behalf.
      MD
    end
end
