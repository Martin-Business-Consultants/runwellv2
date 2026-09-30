class Prompts::UsersController < ApplicationController
  allow_staff
  agent_exempt :index, reason: "the editor’s @mention menu; me lists the team"

  def index
    @users = User.active.people.ordered

    if stale? etag: @users
      render layout: false
    end
  end
end
