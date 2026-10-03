class Current < ActiveSupport::CurrentAttributes
  attribute :session, :access_token, :portal_session, :source, :settings, :ai_over_budget
  # Set only inside Engagement#erase!, the one place sent agreements and decisions may go.
  attribute :erasing

  # The client's contact on the portal: signed in by link, or acting through their token.
  def contact = portal_session&.contact || access_token&.contact

  # Signed in with a browser session, or acting through a bearer token: then as the token's
  # person's agent (User::Agent), so the history says "Ted's agent via Claude".
  def user = session&.user || access_token&.user&.then { it.agent || it.agent! }
  def client_agent? = access_token&.contact.present?
  def agent? = access_token.present?
end
