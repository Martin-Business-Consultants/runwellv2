# Real requests from a project manager, an employee and a client, played through the agent tools
# exactly as a harness would call them (Agent::Dispatch, with each person's token), against this
# install's own records. Everything runs inside a transaction that is rolled back, so nothing is
# kept. `bin/rails agent:scenarios` runs it; run it before a release, and after changing tools.
module Runwell
  class AgentScenarios
    Step = Data.define(:who, :says, :ok, :detail)

    def initialize(out: $stdout, base_url: "http://#{Runwell.host}")
      @out, @base_url, @steps = out, base_url, []
    end

    def run
      ActiveRecord::Base.transaction do
        manager = User.active.people.find { it.role == "manager" } || User.active.people.find { it.role == "owner" }
        member = User.active.people.find { it.role == "member" } || manager
        contact = Contact.active.where(portal_access: true).where.not(email: nil).first ||
          Contact.active.where.not(email: nil).first&.tap { it.update!(portal_access: true) }
        abort "These scenarios need people and clients: run bin/rails db:seed:replant on a development copy." unless manager && contact

        project_manager(manager, member)
        employee(member)
        client(contact)
        raise ActiveRecord::Rollback
      end
      report
    end

    private
      def project_manager(manager, member)
        as(manager, "Sarah (manager)")
        say("What needs me today?", "list_tasks", owner: "me", due: "today") { it["status"] == "ok" }
        client = Client.order(:id).first
        say("Pull up #{client.name.split.first}", "show_client", id: client.name.split.first) { it["status"] == "ok" || it["code"] == "ambiguous" }
        work = Work.where.not(ref: nil).order(:id).first
        say("Catch me up on #{work.title}", "show_work", ref: work.title) { it.dig("work", "ref") == work.ref }
        task = Task.where.not(status: "done").order(:id).first
        if task
          say("Give “#{task.title}” to #{member.first_name}, due Friday", "update_task", id: task.id, task: { owner_id: member.first_name, due_on: Date.current.next_occurring(:friday).iso8601 }) { it["status"] == "ok" && task.reload.owner == member }
        end
        say("Anything new since yesterday?", "changes", since: "24h") { it["cursor"].is_a?(Integer) }
        cursor = @last["cursor"]
        say("…and since then?", "changes", after: cursor) { it["changes"] == [] }
        asked = { title: "Scenario: add a holiday banner", source: "chat", owner_id: "" }
        say("Add that ask as work nobody's on yet (sent twice, as after a timeout)", "create_task", client_id: client.id, task: asked, idempotency_key: "scenario-1") { it["status"] == "ok" }
        say("(the retry)", "create_task", client_id: client.id, task: asked, idempotency_key: "scenario-1") { it["replayed"] == true }
        say("Find “a”", "resolve", q: "a") { it["candidates"].size > 1 }
        work = Work.open.first
        if work
          say("Add a section to #{work.ref}", "add_scope_item", work_ref: work.ref, scope_item: { description: "Scenario: launch" }) { it["status"] == "ok" }
        end
      end

      def employee(member)
        as(member, "#{member.first_name} (#{member.role})")
        say("What am I on?", "list_tasks", owner: "me") { Array(it["tasks"]).any? || Task.open.where(owner: member).none? }
        task = Task.where(owner: member).where.not(status: "done").first
        if task
          say("“#{task.title}” is done, ready for review", "update_task", id: task.title, task: { status: "in_review" }) { task.reload.status == "in_review" || it["code"] == "ambiguous" }
          say("Note that on it", "add_note", record: "Task:#{task.id}", note: { body: "Finished the first pass.", kind: "internal" }) { it["status"] == "ok" }
        end
      end

      def client(contact)
        @token = AccessToken.issue!(contact: contact, name: "Scenario assistant").plaintext
        @who = "#{contact.name} (client)"
        say("Who am I acting for?", "portal_me") { it.dig("me", "company") == contact.client.name }
        say("Where are things at?", "portal_works") { it["status"] == "ok" }
        work = contact.client.works.order(:id).first
        if work
          say("Show me #{work.title}", "portal_work", ref: work.title) { it.dig("work", "ref") == work.ref || it["code"] == "ambiguous" }
        end
        other = Work.where.not(client_id: contact.client_id).where.not(ref: nil).first
        say("Show me #{other.ref} (another client's)", "portal_work", ref: other.ref) { it["code"] == "not_found" } if other
        say("Ask them for a Spanish menu by Friday", "portal_send_request", request: { subject: "Spanish menu by Friday" }) { it["status"] == "ok" }
        say("What have I asked for?", "portal_requests") { it["requests"].any? { |r| r["subject"] == "Spanish menu by Friday" } }
      end

      def as(user, label)
        @token = AccessToken.issue!(user: user, name: "Scenario assistant").plaintext
        @who = label
      end

      def say(words, tool_name, **arguments)
        tool = Agent::Catalogue.find(tool_name) or return record(words, false, "no tool #{tool_name}")
        @last = Agent::Dispatch.new(tool, arguments, token: @token, base_url: @base_url).call
        ok = (yield(@last) rescue false)
        record(words, ok, "#{tool_name}: #{@last["summary"] || @last["status"]}#{" (#{@last["code"]})" if @last["code"]}")
      end

      def record(words, ok, detail) = @steps << Step.new(@who, words, ok, detail)

      def report
        @steps.group_by(&:who).each do |who, steps|
          @out.puts "\n#{who}"
          steps.each { @out.puts "  #{it.ok ? "✓" : "✗"} #{it.says.ljust(52)} #{it.detail.to_s.truncate(90)}" }
        end
        failed = @steps.count { !it.ok }
        @out.puts "\n#{@steps.size} steps, #{failed} failed. Nothing was kept."
        failed.zero?
      end
  end
end
