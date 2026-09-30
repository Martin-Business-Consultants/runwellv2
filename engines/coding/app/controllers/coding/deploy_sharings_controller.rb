# Whether the client sees this repo's production deploys ("Shipped") in their portal.
module Coding
  class DeploySharingsController < ApplicationController
    allow_staff
    agent_tool :share_deploys_with_client, on: :create, title: "Show a repository’s production deploys to the client",
      confirm: "The client will see each successful production deploy of this repository, with its date and description, in their portal."
    agent_tool :stop_sharing_deploys, on: :destroy, title: "Stop showing a repository’s deploys to the client"

    before_action { @repository = Repository.find(params[:repository_id]) }

    def create
      @repository.update!(share_deploys: true)
      redirect_back fallback_location: @repository.linkable, notice: "The client now sees production deploys of #{@repository.name}."
    end

    def destroy
      @repository.update!(share_deploys: false)
      redirect_back fallback_location: @repository.linkable, notice: "Deploys of #{@repository.name} are hidden from the client."
    end
  end
end
