# Everything a local AI needs to do one task and report back, as Markdown: what the task is and
# where it sits, the section it belongs to, what's been said, what else is due, how to
# update Runwell with the `runwell` command (or MCP), and whatever plugins add (the Code plugin
# adds repositories and a branch). Copied by the AI button on a task, and served to agents by
# the brief_task tool. Staff only: it includes internal notes.
class Task::Brief
  attr_reader :task, :base_url, :person

  def initialize(task, base_url:, person:)
    @task = task
    @base_url = base_url.to_s.chomp("/")
    @person = person&.person
  end

  def to_s = sections.compact.join("\n\n") + "\n"

  def summary = "Brief for #{task.title} (Task:#{task.id})"

  private
    def work = task.work
    def record = "Task:#{task.id}"
    def plain(html) = html.present? ? ActionText::Content.new(html.to_s).to_plain_text.strip : nil

    def sections
      [ heading, the_task, agreed_scope, notes, due_alongside, *plugin_sections, working_with_runwell, rules ]
    end

    def heading
      lines = [ "# #{task.title}", "",
        "Runwell work item #{record}: #{base_url}/tasks/#{task.id}",
        "Client: #{task.client&.name || "none matched yet"}",
        ("#{Setting.current.label_name(work.label)}: #{work.ref} #{work.title}" if work),
        ("Requested by: #{task.requester_name} (#{task.source})" if task.requester_name.present?),
        ("#{Setting.current.term(:scope_item)}: #{task.scope_item.description}" if task.scope_item),
        "Status: #{task.status.humanize}" + (task.owner ? " · Lead: #{task.owner.display_name}#{" · Also on it: #{task.other_owners.map(&:display_name).to_sentence}" if task.other_owners.any?}" : " · Unassigned") + (task.due_on ? " · Due: #{task.due_on.iso8601}" : "") ]
      lines.compact.join("\n")
    end

    def the_task
      text = plain(task.description)
      "## The work\n\n#{text.presence || "(No description. Read the notes below, and ask if it's unclear.)"}"
    end

    # Its work's sections, so the task is read against the rest of what the work delivers.
    def agreed_scope
      return unless work

      sections = work.scope_items.map { "- #{it.description}#{" (this one)" if it.id == task.scope_item_id}" }
      return if sections.empty?

      "## #{Setting.current.term(:scope_item, count: 2)} of #{work.ref}\n\n#{sections.join("\n")}"
    end

    def notes
      recent = task.notes.recent.includes(:author).limit(5).to_a
      return if recent.empty?

      "## Recent notes (newest first)\n\n" + recent.map { |n|
        "- #{n.occurred_at.to_date.iso8601} #{n.author&.display_name || "someone"} (#{n.kind}): #{plain(n.body).to_s.squish.truncate(400)}"
      }.join("\n")
    end

    # Other open tasks with a date alongside this one (on its work, else its client): what else
    # has been promised.
    def due_alongside
      home = work || task.client or return
      open = home.tasks.open.where.not(id: task.id).where.not(due_on: nil).includes(:owner).order(:due_on).limit(10).to_a
      return if open.empty?

      "## Other dated work on #{work ? work.ref : home.name}\n\n" +
        open.map { "- #{it.title} · #{it.owner&.display_name || "unassigned"} · due #{it.due_on.iso8601}" }.join("\n")
    end

    def plugin_sections
      Runwell::Plugins.enabled_agent_briefs.values.filter_map do |builder|
        builder.call(task, base_url)&.strip.presence
      rescue => error
        Rails.error.report(error, context: { task: task.id })
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
        runwell show_task --id #{task.id}                                  # the item, fresh
        runwell update_task --id #{task.id} --task.status in_progress      # when you start
        runwell add_note --record #{record} --note.body "What you did, found or decided"
        runwell update_task --id #{task.id} --task.status blocked          # stuck: add a note saying why
        runwell update_task --id #{task.id} --task.status in_review        # finished: a person checks it and marks it done
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
