# Your own GitHub username, so your commits, reviews and repo access are matched to you.
module Coding
  class IdentitiesController < ApplicationController
    allow_staff
    agent_tool :set_my_github_login, on: :update, title: "Set your GitHub username", params: { identity: { github_login: "string" } },
      description: "Blank removes it."

    def update
      redirect_back fallback_location: coding_time_suggestions_path, **Identity.assign(Current.user, params.dig(:identity, :github_login))
    end
  end
end
