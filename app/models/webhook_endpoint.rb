# Settings > Webhooks: an address that hears of every event (or the kinds it names) as signed
# JSON, so other tools (Zapier, n8n, a data warehouse, your own scripts) can follow along without
# a plugin. Sign-in and security events go only to endpoints that ask for them. Twenty failures in
# a row switch an endpoint off.
class WebhookEndpoint < ApplicationRecord
  MAX_FAILURES = 20

  encrypts :secret
  belongs_to :created_by, class_name: "User", optional: true
  has_many :deliveries, class_name: "WebhookDelivery", dependent: :delete_all

  normalizes :url, with: ->(url) { url.to_s.strip }
  validates :url, presence: true, format: { with: %r{\Ahttps?://[^\s/$.?#].[^\s]*\z}i, message: "should start with https:// (or http://)" }
  validates :description, length: { maximum: 120 }

  before_validation { self.secret ||= "whsec_#{SecureRandom.base58(32)}" }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:created_at) }

  # Queue a delivery to every endpoint that wants this event (EventPublishJob).
  def self.dispatch(event)
    active.find_each do |endpoint|
      next unless endpoint.wants?(event)

      delivery = endpoint.deliveries.create!(event: event, kind: event.kind)
      WebhookDeliveryJob.perform_later(delivery)
    end
  end

  def wants?(event)
    return false if Event::SECURITY_SUBJECTS.include?(event.subject_type) && !include_security?

    kinds.blank? || kinds.any? { |kind| kind.end_with?(".*") ? event.kind.start_with?(kind.delete_suffix("*")) : event.kind == kind }
  end

  def kinds_text = Array(kinds).join(", ")
  def kinds_text=(text)
    self.kinds = text.to_s.split(/[\s,]+/).map(&:strip).compact_blank.uniq.presence
  end

  def ping!
    deliveries.create!(kind: "ping").tap { WebhookDeliveryJob.perform_later(it) }
  end

  def delivered!
    update_columns(failures_in_a_row: 0, last_delivered_at: Time.current)
  end

  def failed!
    increment!(:failures_in_a_row)
    return unless failures_in_a_row >= MAX_FAILURES && active?

    update!(active: false)
    Setting.current.record_event!("settings.webhook", actor: nil, actor_label: "Runwell", source: "app",
      payload: { url: url, active: false, reason: "#{MAX_FAILURES} failures in a row" })
  end
end
