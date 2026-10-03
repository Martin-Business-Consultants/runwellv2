# A person's yes to an OAuth client: a single-use code, good for ten minutes, bound to the
# redirect URI it was issued for and to a PKCE challenge (S256).
class OauthGrant < ApplicationRecord
  LIFETIME = 10.minutes

  belongs_to :oauth_client
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  attr_reader :code

  def self.issue!(client:, redirect_uri:, code_challenge:, user: nil, contact: nil, read_only: false)
    code = SecureRandom.urlsafe_base64(32)
    create!(oauth_client: client, user: user, contact: contact, redirect_uri: redirect_uri, code_challenge: code_challenge, read_only: read_only,
      code_digest: AccessToken.digest(code), expires_at: LIFETIME.from_now).tap { it.instance_variable_set(:@code, code) }
  end

  # Trade a code for a token, once. Returns the AccessToken, or nil if anything doesn't match.
  def self.redeem!(code:, client:, redirect_uri:, code_verifier:)
    grant = find_by(code_digest: AccessToken.digest(code), oauth_client: client)
    return unless grant && grant.used_at.nil? && grant.expires_at.future? && grant.redirect_uri == redirect_uri && grant.verifies?(code_verifier)
    return unless grant.user ? grant.user.active? : grant.contact&.portal?

    transaction do
      grant.update!(used_at: Time.current)
      AccessToken.issue!(user: grant.user, contact: grant.contact, name: client.name, kind: "oauth", oauth_client: client, read_only: grant.read_only)
    end
  end

  def verifies?(verifier)
    return false if verifier.blank?

    challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(challenge, code_challenge)
  end
end
