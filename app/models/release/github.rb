# The few calls updating makes to GitHub's REST API: the latest release, and for installs that
# update through GitHub Actions, starting and following the deploy workflow.
#
#   RUNWELL_RELEASES_REPO   where releases are published (owner/name)
#   RUNWELL_GITHUB_TOKEN    only to start a deploy (a fine-grained token: Actions read and
#                           write); the repository is public, so reading releases needs none
require "net/http"

class Release::Github
  class Error < StandardError; end

  DEFAULT_REPO = "Martin-Business-Consultants/runwellv2"

  def self.repo = ENV["RUNWELL_RELEASES_REPO"].presence || DEFAULT_REPO
  def self.token = ENV["RUNWELL_GITHUB_TOKEN"].presence

  def get(path, params = {})
    uri = uri_for(path)
    uri.query = URI.encode_www_form(params) if params.any?
    request Net::HTTP::Get.new(uri)
  end

  def post(path, body)
    request(Net::HTTP::Post.new(uri_for(path)).tap { it.body = body.to_json; it["Content-Type"] = "application/json" })
  end

  private
    def uri_for(path) = URI("https://api.github.com/repos/#{self.class.repo}/#{path}")

    def request(request)
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["User-Agent"] = "Runwell/#{Runwell::VERSION}"
      request["Authorization"] = "Bearer #{self.class.token}" if self.class.token

      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { it.request(request) }
      raise Error, failure(response) unless response.is_a?(Net::HTTPSuccess)

      response.body.present? ? JSON.parse(response.body) : {}
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
      raise Error, "Couldn't reach GitHub (#{error.message})."
    end

    def failure(response)
      message = JSON.parse(response.body.to_s)["message"] rescue nil
      case response.code.to_i
      when 401 then self.class.token ? "GitHub refused RUNWELL_GITHUB_TOKEN: it's wrong or has expired." : "GitHub needs RUNWELL_GITHUB_TOKEN for that."
      when 403 then "GitHub refused: #{message || "the token lacks access"}."
      when 404 then "GitHub has no releases for #{self.class.repo} that this install can see#{" (a private repository needs RUNWELL_GITHUB_TOKEN)" unless self.class.token}."
      else "GitHub answered #{response.code}#{": #{message}" if message}."
      end
    end
end
