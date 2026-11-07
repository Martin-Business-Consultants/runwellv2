# Where people reach this install (Settings > Address): every emailed link points there. Typed as a
# host or a whole URL.
module Setting::Address
  extend ActiveSupport::Concern

  included do
    normalizes :app_host, with: ->(value) { value.to_s.strip.downcase.sub(%r{\A[a-z]+://}, "").sub(%r{[/?#].*\z}, "").presence }
    validates :app_host, format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:\d+)?\z/, message: "should be a domain, like runwell.example.com" }, allow_nil: true
    validates :app_protocol, inclusion: { in: %w[https http] }, allow_nil: true
  end

  class_methods do
    def human_attribute_name(attribute, options = {}) = attribute.to_s == "app_host" ? "Address" : super
  end

  # Takes "https://runwell.example.com/" or a bare host, which means https.
  def app_url=(url)
    self.app_protocol = url.to_s.strip[%r{\A(https?)://}i, 1]&.downcase || "https"
    self.app_host = url
  end
end
