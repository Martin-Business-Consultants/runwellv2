module AccountManagement
  # What account management puts on a person's home page before a standard is missed: agendas
  # due, recaps owed, their weekly update on Friday, and accounts on their clients that someone
  # else owns, that we can't get into, or whose token is about to run out. A meeting without an
  # owner goes to the client's lead; a client without a lead goes to whoever may manage accounts.
  module Attention
    extend self

    def items(user)
      meetings(user) + updates(user) + accesses(user) + unled_clients(user)
    end

    def responsible?(user, meeting)
      return meeting.owner == user if meeting.owner

      lead = meeting.client.account_lead
      lead ? lead.user == user : user.can?(:manage_accounts)
    end

    private
      def meetings(user)
        agendas = Meeting.needing_agenda.includes(:owner, client: :account_lead).select { it.state == "agenda_due" }
        recaps = Meeting.needing_recap.where(starts_at: 30.days.ago..).includes(:owner, client: :account_lead)
        (agendas + recaps.to_a).select { responsible?(user, it) }
      end

      # This week's from Friday, and last week's if it never went out.
      def updates(user)
        return [] unless WeeklyUpdate.owed_by?(user)

        this_week = WeeklyUpdate.week_of
        weeks = [ this_week - 7 ]
        weeks << this_week if Date.current >= this_week + (Playbook::UPDATE_DAY - 1)
        weeks.filter_map do |week|
          update = user.weekly_updates.find_or_initialize_by(week_of: week)
          update unless update.sent? || (week < this_week && !Lead.where(user: user).where(created_at: ..update.due_at).exists?)
        end
      end

      # Only what stops work or is about to: ownership, access and tokens. Stale checks wait in
      # the register.
      def accesses(user)
        led = Lead.clients_for(user)
        scope = user.can?(:manage_accounts) ? Access.where(client_id: led).or(Access.where.not(client_id: Lead.select(:client_id))) : Access.where(client_id: led)
        scope.includes(:client).ordered.select { urgent?(it) }
      end

      def urgent?(access)
        %w[third_party unknown].include?(access.owned_by) || %w[none requested].include?(access.our_access) || access.token_problem
      end

      def unled_clients(user)
        return [] unless user.can?(:manage_accounts)

        ::Client.active.where.not(id: Lead.select(:client_id)).ordered.to_a
      end
  end
end
