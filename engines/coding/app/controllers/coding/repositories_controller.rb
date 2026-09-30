# Linking a repo to a client, engagement or todo (from the quick action tray), changing how
# it's set up, or letting go of it.
module Coding
  class RepositoriesController < ApplicationController
    allow_staff
    agent_tool :link_repository, on: :create, title: "Link a git repository",
      description: "record: \"Type:id\" for a Client, Engagement or Todo (a scope item goes to its engagement, a request to its client). A todo uses its engagement's repos unless it has its own, and an engagement its client's. url: any git remote. setup_notes: how to get it running and where secrets live (never the secrets).",
      params: { record: "string!", repository: { url: "string!", default_branch: "string", path: "string", staging_url: "string", production_url: "string", setup_notes: "text" } }
    agent_tool :update_repository, on: :update, title: "Change a linked repository",
      params: { repository: { url: "string", default_branch: "string", path: "string", staging_url: "string", production_url: "string", setup_notes: "text" } }
    agent_tool :unlink_repository, on: :destroy, title: "Unlink a repository", description: "Only unlinks it here. Nothing changes in the repository."

    before_action :set_repository, only: %i[update destroy]

    def create
      linkable = Repository.linkable_for(QuickAction.locate(params[:record], QuickAction::RECORD_TYPES)) if params[:record].present?
      return redirect_back(fallback_location: root_path, alert: "Choose a client, engagement or todo for the repository.") unless linkable

      repository = Repository.new(repository_params.merge(linkable: linkable, added_by: Current.user))
      if repository.save
        linkable.record_event!("coding.repository_linked", payload: { repository: repository.name })
        redirect_back fallback_location: linkable, notice: "Linked #{repository.name}."
      else
        redirect_back fallback_location: linkable, alert: repository.errors.full_messages.to_sentence
      end
    end

    def update
      if @repository.update(repository_params)
        redirect_back fallback_location: @repository.linkable, notice: "Saved #{@repository.name}."
      else
        redirect_back fallback_location: @repository.linkable, alert: @repository.errors.full_messages.to_sentence
      end
    end

    def destroy
      return redirect_back(fallback_location: @repository.linkable, alert: "Only whoever linked it, or someone who may delete records, can unlink it.") unless @repository.deletable_by?(Current.user)

      @repository.destroy!
      @repository.linkable.record_event!("coding.repository_unlinked", payload: { repository: @repository.name })
      redirect_back fallback_location: @repository.linkable, notice: "Unlinked #{@repository.name}."
    end

    private
      def set_repository = @repository = Repository.find(params[:id])
      def repository_params = params.expect(repository: %i[url default_branch path staging_url production_url setup_notes])
  end
end
