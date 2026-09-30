# Who the caller is: their role, what it lets them do, the team (for owners of work and
# commitments), and which agent tools their role withholds and why.
class MeController < ApplicationController
  allow_staff
  agent_tool :me, on: :show, title: "Who am I, and what can I do",
    description: "Your name and role, what your role allows, the team (ids for owners), and the tools you are not offered and why. Call this when something is forbidden or a list is empty."

  def show
    @user = current_user
    @team = User.active.people.ordered
    @withheld = Agent::Catalogue.withheld_from(@user)
  end
end
