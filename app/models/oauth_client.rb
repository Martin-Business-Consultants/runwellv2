# An app that registered itself to sign people in (RFC 7591), like Claude or ChatGPT. Public
# clients only: no secret, so every sign-in proves itself with PKCE instead.
class OauthClient < ApplicationRecord
  has_many :grants, class_name: "OauthGrant", dependent: :delete_all
  has_many :access_tokens, dependent: :destroy

  validates :name, :uid, presence: true
  validate :redirect_uris_are_safe

  before_validation { self.uid ||= SecureRandom.uuid }

  def redirect_uri?(uri) = Array(redirect_uris).include?(uri)

  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

  # A desktop app (Claude Code, the runwell CLI) signs in by listening on the person's own
  # computer, so its callback is a loopback address, never a domain (RFC 8252).
  def self.loopback?(uri) = URI.parse(uri.to_s).host.in?(LOOPBACK_HOSTS)

  private
    # https anywhere, or http only back to this machine (the CLI's loopback sign-in).
    def redirect_uris_are_safe
      uris = Array(redirect_uris)
      errors.add(:redirect_uris, "are required") if uris.empty?
      uris.each do |uri|
        parsed = URI.parse(uri.to_s)
        ok = parsed.scheme == "https" || (parsed.scheme == "http" && LOOPBACK_HOSTS.include?(parsed.host))
        errors.add(:redirect_uris, "must be https or a local loopback address") unless ok && parsed.fragment.nil?
      rescue URI::InvalidURIError
        errors.add(:redirect_uris, "include an invalid address")
      end
    end
end
