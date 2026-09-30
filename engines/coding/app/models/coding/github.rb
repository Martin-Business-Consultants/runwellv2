module Coding
  # GitHub's REST API, as much of it as Runwell reads: pull requests and their checks, the
  # people who can reach a repo, and adding the webhook. It never pushes code or changes a
  # repo's contents.
  class Github
    require "net/http"

    API = "https://api.github.com"

    class Error < StandardError; end

    def initialize(connection = Connection.current)
      raise Error, "GitHub isn’t connected. Connect it in Settings > Code." unless connection&.connected?

      @connection = connection
    end

    # The newest pull request from a branch, or nil.
    def pull_for(full_name, branch)
      owner = full_name.split("/").first
      get("/repos/#{full_name}/pulls", head: "#{owner}:#{branch}", state: "all", per_page: 1).first
    end

    # "success", "failure" or "pending" across a commit's check suites, or nil when none ran.
    def checks_for(full_name, sha)
      suites = get("/repos/#{full_name}/commits/#{sha}/check-suites").fetch("check_suites", [])
      conclusions = suites.map { it["conclusion"] }
      return if conclusions.empty?
      return "pending" if conclusions.include?(nil)

      conclusions.all? { it.in?(%w[success neutral skipped]) } ? "success" : "failure"
    end

    def collaborators(full_name) = get("/repos/#{full_name}/collaborators", per_page: 100).map { it["login"].downcase }

    def create_hook(full_name, url:, secret:)
      post("/repos/#{full_name}/hooks", name: "web", active: true,
        events: %w[pull_request pull_request_review check_suite deployment_status issues push],
        config: { url: url, content_type: "json", secret: secret })
    end

    def user = get("/user")

    private
      def get(path, **query)
        uri = URI(API + path)
        uri.query = query.to_query if query.any?
        request(Net::HTTP::Get.new(uri))
      end

      def post(path, body)
        request = Net::HTTP::Post.new(URI(API + path))
        request.body = body.to_json
        request["Content-Type"] = "application/json"
        request(request)
      end

      def request(request)
        request["Authorization"] = "Bearer #{@connection.access_token}"
        request["Accept"] = "application/vnd.github+json"
        request["X-GitHub-Api-Version"] = "2022-11-28"
        uri = request.uri
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { it.request(request) }
        body = response.body.present? ? JSON.parse(response.body) : {}
        return body if response.is_a?(Net::HTTPSuccess)

        raise Error, "GitHub refused #{request.method} #{uri.path} (#{response.code}): #{body["message"] || response.body.to_s.truncate(200)}"
      rescue JSON::ParserError
        raise Error, "GitHub sent something that isn’t JSON (#{response&.code})"
      end
  end
end
