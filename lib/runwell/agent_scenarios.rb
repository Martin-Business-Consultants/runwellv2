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
        say("What needs me today?", "briefing") { it["status"] == "ok" }
        client = Client.order(:id).first
        say("Pull up #{client.name.split.first}", "show_client", id: client.name.split.first) { it["status"] == "ok" || it["code"] == "ambiguous" }
        engagement = Engagement.where.not(ref: nil).order(:id).first
        say("Catch me up on #{engagement.title}", "show_engagement", ref: engagement.title) { it.dig("engagement", "ref") == engagement.ref }
        todo = Todo.where.not(status: "done").order(:id).first
        if todo
          say("Give “#{todo.title}” to #{member.first_name}, due Friday", "update_work", id: todo.id, todo: { owner_id: member.first_name, due_on: Date.current.next_occurring(:friday).iso8601 }) { it["status"] == "ok" && todo.reload.owner == member }
        end
        say("Anything new since yesterday?", "changes", since: "24h") { it["cursor"].is_a?(Integer) }
        cursor = @last["cursor"]
        say("…and since then?", "changes", after: cursor) { it["changes"] == [] }
        request = { subject: "Scenario: add a holiday banner", source: "chat", client_id: client.id }
        say("Log that request (sent twice, as after a timeout)", "create_request", request: request, idempotency_key: "scenario-1") { it["status"] == "ok" }
        say("(the retry)", "create_request", request: request, idempotency_key: "scenario-1") { it["replayed"] == true }
        say("Find “a”", "resolve", q: "a") { it["candidates"].size > 1 }
        draft = AgreementVersion.where(sent_at: nil).includes(:engagement, :scope_items).find { !it.engagement.internal? && it.scope_items.any? }
        if draft
          say("Send the #{draft.engagement.ref} draft", "send_agreement", engagement_ref: draft.engagement.ref, id: draft.id) { it["status"] == "needs_confirmation" }
        end
      end

      def employee(member)
        as(member, "#{member.first_name} (#{member.role})")
        say("What am I on?", "list_work", owner: "me") { Array(it["work"]).any? || Todo.open.where(owner: member).none? }
        todo = Todo.where(owner: member).where.not(status: "done").first
        if todo
          say("“#{todo.title}” is done, ready for review", "update_work", id: todo.title, todo: { status: "in_review" }) { todo.reload.status == "in_review" || it["code"] == "ambiguous" }
          say("Note that on it", "add_note", record: "Todo:#{todo.id}", note: { body: "Finished the first pass.", kind: "internal" }) { it["status"] == "ok" }
        end
      end

      def client(contact)
        @token = AccessToken.issue!(contact: contact, name: "Scenario assistant").plaintext
        @who = "#{contact.name} (client)"
        say("Who am I acting for?", "portal_me") { it.dig("me", "company") == contact.client.name }
        say("Where are things at?", "portal_engagements") { it["status"] == "ok" }
        engagement = contact.client.engagements.order(:id).first
        if engagement
          say("Show me #{engagement.title}", "portal_engagement", ref: engagement.title) { it.dig("engagement", "ref") == engagement.ref || it["code"] == "ambiguous" }
          if engagement.pending_version && contact.can_approve?
            say("Approve it", "portal_decide", engagement_ref: engagement.ref, decision: "approved", approver_name: contact.name) { it["status"] == "needs_confirmation" }
          end
        end
        other = Engagement.where.not(client_id: contact.client_id).where.not(ref: nil).first
        say("Show me #{other.ref} (another client's)", "portal_engagement", ref: other.ref) { it["code"] == "not_found" } if other
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
