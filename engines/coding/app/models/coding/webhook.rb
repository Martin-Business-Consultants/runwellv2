module Coding
  # One delivery from GitHub, already verified. Each event updates what Runwell knows about a
  # repo's branches, deploys, commits and issues, and records the moments that matter on the
  # engagement's timeline. A repo linked in several places (a client and one of its
  # engagements) is one GitHub repo, so each row hears about it.
  class Webhook
    def initialize(event, payload)
      @event, @payload = event.to_s, payload
    end

    def process!
      return if repositories.empty?

      case @event
      when "pull_request" then pull_request
      when "pull_request_review" then review
      when "check_suite" then check_suite
      when "deployment_status" then deployment_status
      when "issues" then issue
      when "push" then push
      end
    end

    private
      def repositories = @repositories ||= Repository.find_by_full_name(@payload.dig("repository", "full_name")).includes(:engagement, :client).to_a
      def connection = Connection.current

      def pull_request
        pr = @payload["pull_request"]
        each_branch(pr.dig("head", "ref")) do |branch|
          was = branch.pr_state
          branch.update!(pr_number: pr["number"], pr_url: pr["html_url"], pr_title: pr["title"], pr_state: pr_state(pr),
            merged_at: pr["merged_at"], review_requested: pr["requested_reviewers"].present?)
          todo = branch.todo
          if branch.pr_state == "open" && was.nil?
            todo.record_event!("coding.pull_request_opened", payload: { repository: branch.repository.name, number: pr["number"] })
          elsif branch.pr_state == "merged" && was != "merged"
            todo.record_event!("coding.merged", payload: { repository: branch.repository.name, number: pr["number"] })
            # update, not update!: a rule on the todo (a QA check still to pass) may keep it open.
            todo.update(status: "done") if connection&.close_work_on_merge && todo.status != "done"
          end
        end
      end

      def review
        return unless @payload["action"] == "submitted"

        pr = @payload["pull_request"]
        each_branch(pr.dig("head", "ref")) do |branch|
          branch.update!(review_requested: false)
          branch.todo.record_event!("coding.reviewed", payload: { number: pr["number"], by: @payload.dig("review", "user", "login"), state: @payload.dig("review", "state") })
        end
      end

      def check_suite
        suite = @payload["check_suite"]
        state = case suite["conclusion"]
        when nil then "pending"
        when "success", "neutral", "skipped" then "success"
        else "failure"
        end
        each_branch(suite["head_branch"]) { it.update!(checks_state: state) }
      end

      # A successful production deploy lands on the timeline of each engagement the repo serves.
      def deployment_status
        deployment, status = @payload["deployment"], @payload["deployment_status"]
        shipped = []
        repositories.each do |repository|
          deploy = repository.deploys.find_or_initialize_by(github_id: deployment["id"])
          deploy.update!(environment: deployment["environment"], state: status["state"], sha: deployment["sha"], ref: deployment["ref"],
            url: status["environment_url"].presence || status["target_url"], description: status["description"], deployed_at: status["created_at"] || Time.current)
          shipped |= repository.engagements if deploy.production? && deploy.succeeded? && deploy.saved_change_to_state?
        end
        shipped.each { it.record_event!("coding.deployed", payload: { repository: repositories.first.name, environment: deployment["environment"], sha: deployment["sha"].to_s.first(7) }) }
      end

      # An issue with the client label becomes a request to triage, once.
      def issue
        issue = @payload["issue"]
        return unless @payload["action"].in?(%w[opened labeled])
        return unless issue["labels"].to_a.any? { it["name"].to_s.casecmp?(connection&.issue_label.to_s) }
        return if Issue.where(repository: repositories, number: issue["number"]).exists?

        repository = repositories.find(&:engagement) || repositories.first
        request = ::Request.create!(client: repository.client, subject: issue["title"].to_s.truncate(200), source: "github",
          sender_name: issue.dig("user", "login"), body: request_body(issue))
        request.record_event!("request.received", payload: { repository: repository.name, issue: issue["number"] })
        Issue.create!(repository: repository, number: issue["number"], request: request)
      end

      def push
        name = @payload["ref"].to_s.delete_prefix("refs/heads/")
        each_branch(name) do |branch|
          @payload["commits"].to_a.each do |commit|
            branch.repository.commits.find_or_create_by!(sha: commit["id"]) do |record|
              record.todo = branch.todo
              record.author_login = commit.dig("author", "username")
              record.user = Identity.user_for(record.author_login)
              record.message = commit["message"].to_s.lines.first.to_s.strip.truncate(250)
              record.committed_at = commit["timestamp"] || Time.current
            end
          end
        end
      end

      def each_branch(name, &)
        return if name.blank?

        repositories.filter_map { Branch.locate(it, name) }.each(&)
      end

      def pr_state(pr)
        if pr["merged_at"] || pr["merged"] then "merged"
        elsif pr["state"] == "closed" then "closed"
        elsif pr["draft"] then "draft"
        else "open"
        end
      end

      def request_body(issue)
        text = ERB::Util.html_escape(issue["body"].to_s).split(/\n{2,}/).map { "<p>#{it.gsub("\n", "<br>")}</p>" }.join
        "#{text}<p><a href=\"#{ERB::Util.html_escape(issue["html_url"])}\">GitHub issue ##{issue["number"]}</a></p>"
      end
  end
end
