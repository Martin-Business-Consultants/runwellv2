# Settings > Code: the GitHub connection, the webhook, what happens on a merge or a labelled
# issue, people's GitHub usernames and every linked repository.
module Coding
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_code_settings, on: :show, title: "Show the GitHub connection and linked repositories"
    agent_tool :update_code_settings, on: :update, title: "Change GitHub credentials and code settings",
      description: "issue_label: GitHub issues with this label become requests. close_work_on_merge: a merged pull request marks its todo done.",
      params: { connection: { client_id: "string", client_secret: "string", issue_label: "string", close_work_on_merge: "boolean" } }
    agent_tool :disconnect_github, on: :destroy, title: "Disconnect GitHub"

    before_action { @connection = Connection.for_settings }

    def show
      @repositories = Repository.includes(:linkable, :client).order(:full_name, :url)
      @people = ::User.active.people.ordered.includes(:coding_identity)
    end

    def update
      if @connection.update(connection_params)
        redirect_to coding_settings_path, notice: @connection.connected? ? "Saved." : "Saved. Now sign in with GitHub to connect."
      else
        redirect_to coding_settings_path, alert: @connection.errors.full_messages.to_sentence
      end
    end

    def destroy
      Oauth.new(@connection).revoke!
      @connection.disconnect!
      redirect_to coding_settings_path, notice: "Disconnected from GitHub. Linked repositories stay."
    end

    private
      # The secret is write-only on the page: a blank field keeps what is saved.
      def connection_params
        params.expect(connection: %i[client_id client_secret issue_label close_work_on_merge])
          .reject { |key, value| key == "client_secret" && value.blank? }
      end
  end
end
