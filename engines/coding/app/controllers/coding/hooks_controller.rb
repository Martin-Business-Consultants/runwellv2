# Adds Runwell's webhook to a GitHub repo, so pull requests, checks, deploys, issues and
# pushes arrive as they happen. Needs admin on the repo for whoever connected GitHub.
module Coding
  class HooksController < ApplicationController
    allow_staff
    agent_tool :add_github_webhook, on: :create, title: "Add Runwell’s webhook to a GitHub repository"

    def create
      repository = Repository.find(params[:repository_id])
      return redirect_back(fallback_location: repository.linkable, alert: "Only GitHub repositories take the webhook.") unless repository.github?

      connection = Connection.current
      hook = Github.new(connection).create_hook(repository.full_name, url: coding_github_webhooks_url, secret: connection.webhook_secret)
      Repository.find_by_full_name(repository.full_name).update_all(webhook_id: hook["id"])
      redirect_back fallback_location: repository.linkable, notice: "GitHub now tells Runwell about #{repository.name}."
    rescue Github::Error => e
      redirect_back fallback_location: repository.linkable, alert: e.message
    end
  end
end
