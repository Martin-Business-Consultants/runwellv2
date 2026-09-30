# Settings > Code: someone's GitHub username.
module Coding
  class PeopleController < ApplicationController
    require_permission :manage_people
    agent_tool :set_github_login, on: :update, title: "Set someone’s GitHub username",
      params: { person: { user_id: "integer!", github_login: "string" } }, description: "Blank removes it."

    def update
      person = params.expect(person: %i[user_id github_login])
      redirect_to coding_settings_path, **Identity.assign(::User.find(person[:user_id]), person[:github_login])
    end
  end
end
