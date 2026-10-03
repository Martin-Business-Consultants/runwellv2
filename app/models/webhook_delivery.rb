require "net/http"

# One event sent to one webhook endpoint: what was sent, how it went, how many tries. The body is
# signed with the endpoint's secret (X-Runwell-Signature: sha256=HMAC of "timestamp.body"), so the
# receiver can tell it came from this install and wasn't replayed later.
class WebhookDelivery < ApplicationRecord
  KEEP_FOR = 30.days
  class Failed < StandardError; end

  belongs_to :webhook_endpoint
  belongs_to :event, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def self.expire_old! = where(created_at: ...KEEP_FOR.ago).delete_all

  def ok? = status_code.to_i.between?(200, 299)

  def deliver!
    body = JSON.generate(body_hash)
    timestamp = Time.current.to_i.to_s
    uri = URI(webhook_endpoint.url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "Runwell/#{Runwell::VERSION} (+#{Runwell.host})"
    request["X-Runwell-Event"] = kind
    request["X-Runwell-Delivery"] = id.to_s
    request["X-Runwell-Timestamp"] = timestamp
    request["X-Runwell-Signature"] = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", webhook_endpoint.secret, "#{timestamp}.#{body}")}"
    request.body = body

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { it.request(request) }
    finish(status_code: response.code.to_i, error: (response.message.truncate(200) unless response.is_a?(Net::HTTPSuccess)), started: started)
  rescue Failed
    raise
  rescue StandardError => error
    finish(status_code: nil, error: "#{error.class}: #{error.message}".truncate(200), started: started)
  end

  def body_hash
    return { id: "ping-#{id}", kind: "ping", occurred_at: Time.current.utc.iso8601, install: Runwell.host, message: "A test from Settings › Webhooks." } unless event

    {
      id: event.id,
      kind: event.kind,
      occurred_at: event.occurred_at.utc.iso8601,
      install: Runwell.host,
      source: event.source,
      actor: { name: event.actor_name, user_id: event.actor_user_id, via: (event.actor if event.source == "agent") },
      subject: { type: event.subject_type, id: event.subject_id, name: subject_name, url: subject_url },
      payload: event.payload || {}
    }
  end

  private
    def finish(status_code:, error:, started:)
      update!(attempts: attempts + 1, status_code: status_code, error: error,
        duration_ms: started && ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
        delivered_at: (Time.current if status_code.to_i.between?(200, 299)))
      if ok?
        webhook_endpoint.delivered!
      else
        webhook_endpoint.failed!
        raise Failed, error.to_s
      end
    end

    def subject_name
      subject = event.subject
      subject.try(:display_name) || subject.try(:name) || subject.try(:title) || subject.try(:subject)
    end

    def subject_url
      return if Event::SECURITY_SUBJECTS.include?(event.subject_type) || event.subject.nil?

      Rails.application.routes.url_helpers.polymorphic_url(event.subject, host: Runwell.host, protocol: Runwell.protocol)
    rescue NoMethodError, ActionController::UrlGenerationError
      nil
    end
end
