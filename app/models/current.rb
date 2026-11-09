class Current < ActiveSupport::CurrentAttributes
  attribute :session, :access_token, :portal_session, :source, :settings
  # Someone on staff viewing the portal as this contact (Contacts::PreviewsController): read-only.
  attribute :preview_contact
  # Set only inside Work#erase!, so plugins' records that refuse deletion know it's an erase.
  attribute :erasing
  # Every WorkType, read once per request (WorkType.cached).
  attribute :work_types

  # The client's contact on the portal: signed in by link, or acting through their token.
  def contact = preview_contact || portal_session&.contact || access_token&.contact
  def previewing? = preview_contact.present?

  # Signed in with a browser session, or acting through a bearer token: then as the token's
  # person's agent (User::Agent), so the history says "Ted's agent via Claude".
  def user = session&.user || access_token&.user&.then { it.agent || it.agent! }
  def client_agent? = access_token&.contact.present?
  def agent? = access_token.present?
end
