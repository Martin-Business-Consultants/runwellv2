class Current < ActiveSupport::CurrentAttributes
  attribute :session, :access_token, :portal_session, :source, :settings
  delegate :contact, to: :portal_session, allow_nil: true

  # Signed in with a browser session, or acting through a bearer token: then as the token's
  # person's agent (User::Agent), so the history says "Ted's agent via Claude".
  def user = session&.user || access_token&.user&.then { it.agent || it.agent! }
  def agent? = access_token.present?
end
