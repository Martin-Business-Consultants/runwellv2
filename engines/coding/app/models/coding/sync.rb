module Coding
  # What the nightly job and "Sync now" do: catch up on pull requests and checks for open
  # branches in case a webhook was missed, and refresh who can reach each repo. One repo
  # failing doesn't stop the rest; the errors are kept for Settings > Code.
  class Sync
    def initialize(github = Github.new)
      @github = github
      @errors = []
    end

    def run!
      Branch.joins(:repository).merge(Repository.github).where(pr_state: [ nil, "draft", "open" ]).includes(:repository).find_each { refresh_branch(it) }
      Repository.github.distinct.pluck(:full_name).each { refresh_collaborators(it) }
      connection = Connection.current
      @errors.any? ? connection.note_error!(@errors.first(3).join(" ")) : connection.note_sync!
      @errors
    end

    private
      def refresh_branch(branch)
        pr = @github.pull_for(branch.repository.full_name, branch.name) or return
        state = if pr["merged_at"] then "merged" elsif pr["state"] == "closed" then "closed" elsif pr["draft"] then "draft" else "open" end
        checks = @github.checks_for(branch.repository.full_name, pr.dig("head", "sha"))
        branch.update!(pr_number: pr["number"], pr_url: pr["html_url"], pr_title: pr["title"], pr_state: state,
          merged_at: pr["merged_at"], checks_state: checks || branch.checks_state, review_requested: pr["requested_reviewers"].present?)
      rescue Github::Error => e
        @errors << "#{branch.repository.name}: #{e.message}"
      end

      def refresh_collaborators(full_name)
        logins = @github.collaborators(full_name)
        Repository.find_by_full_name(full_name).each do |repository|
          repository.collaborators.where.not(login: logins).delete_all
          (logins - repository.collaborators.pluck(:login)).each { repository.collaborators.create!(login: it) }
        end
      rescue Github::Error => e
        @errors << "#{full_name}: #{e.message}"
      end
  end
end
