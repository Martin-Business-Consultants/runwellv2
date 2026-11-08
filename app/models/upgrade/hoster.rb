# Updates an install that runs on KamalCloud (Hoster) the way bumping its image there would: it
# moves the app's image to the release's tag and starts a deploy of this environment through
# KamalCloud's API. kamal-proxy starts the new container beside this one, which backs up and
# migrates on boot, and switches to it only once it answers its health check: no downtime, and a
# release that can't boot never replaces the one that's running. This install then runs the new
# version, which settles the upgrade; a deploy that fails or is cancelled fails it.
#
#   HOSTER_URL, HOSTER_APP, HOSTER_ENVIRONMENT  where the install lives (set by KamalCloud's Runwell
#                                               template); HOSTER_TOKEN, or the token saved in
#                                               Settings > Updates, an admin's from there
class Upgrade::Hoster
  class Error < StandardError; end

  def self.url = ENV["HOSTER_URL"].presence&.delete_suffix("/")
  def self.app = ENV["HOSTER_APP"].presence
  def self.environment = ENV["HOSTER_ENVIRONMENT"].presence
  def self.token = ENV["HOSTER_TOKEN"].presence || Setting.current.hoster_token.presence

  # Running on KamalCloud at all (a token may still be missing).
  def self.placed? = url.present? && app.present? && environment.present?
  def self.available? = placed? && token.present?

  def initialize(upgrade)
    @upgrade = upgrade
  end

  def start
    image = get("apps/#{self.class.app}.json").dig("app", "template_image").to_s
    raise Error, "KamalCloud didn’t say which image this app runs." if image.blank?

    patch("apps/#{self.class.app}.json", app: { template_image: image.sub(/:[^:\/]+\z/, "") + ":#{@upgrade.to_version}" })
    deployment = post("environments/#{self.class.environment}/deployments.json", app_deployment: { kind: "deploy" })["deployment"].to_h
    @upgrade.update!(external_id: deployment["id"].to_s, external_url: deployment["url"])
  end

  # Fails the upgrade when its deploy ended without deploying. One that succeeded is left for the
  # new version's boot to settle.
  def check
    return if @upgrade.external_id.blank?

    deployment = get("environments/#{self.class.environment}/deployments/#{@upgrade.external_id}.json")["deployment"].to_h
    return unless deployment["status"].in?(%w[failed cancelled])

    @upgrade.fail! "The deploy on KamalCloud #{deployment["status"]}#{": #{deployment["error"]}" if deployment["error"].present?}. Its log says why."
  end

  def where_to_look = "The deploy’s log on KamalCloud says what happened."

  private
    def get(path) = request(Net::HTTP::Get.new(uri(path)))
    def post(path, body) = request(with_body(Net::HTTP::Post.new(uri(path)), body))
    def patch(path, body) = request(with_body(Net::HTTP::Patch.new(uri(path)), body))

    def uri(path) = URI("#{self.class.url}/#{path}")

    def with_body(request, body)
      request.tap { it.body = body.to_json; it["Content-Type"] = "application/json" }
    end

    def request(request)
      request["Authorization"] = "Bearer #{self.class.token}"
      request["Accept"] = "application/json"
      request["User-Agent"] = "Runwell/#{Runwell::VERSION}"
      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: request.uri.scheme == "https", open_timeout: 10, read_timeout: 30) { it.request(request) }
      body = JSON.parse(response.body.presence || "{}") rescue {}
      return body if response.is_a?(Net::HTTPSuccess)

      raise Error, case response.code.to_i
      when 401 then "KamalCloud refused the token: save a new one in Settings > Updates."
      when 403 then "The token’s person can’t deploy this app on KamalCloud: it needs an admin’s."
      when 409 then "Another deploy is already running on KamalCloud; try again once it’s done."
      else "KamalCloud answered #{response.code}: #{Array(body["errors"]).to_sentence.presence || response.message}"
      end
    end
end
