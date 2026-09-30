# Where GitHub delivers events. Public, so every delivery must carry GitHub's signature over
# the body with the connection's webhook secret; anything else is refused.
module Coding
  class WebhooksController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      connection = Connection.current
      return head(:unauthorized) unless connection&.verify_signature(request.raw_post, request.headers["X-Hub-Signature-256"])

      event = request.headers["X-GitHub-Event"]
      return head(:ok) if event == "ping"

      Current.source = "github"
      Webhook.new(event, JSON.parse(request.raw_post)).process!
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end
  end
end
