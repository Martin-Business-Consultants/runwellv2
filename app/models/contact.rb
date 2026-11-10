# Someone at a client: a user with the client role (User::Role::CLIENT), so the team and the
# people they work for are one kind of person, listed together in Users. A contact never signs in
# to the staff app and has no permissions; with portal_access they sign in to the client portal by
# emailed link, and can_approve lets them say yes for their company (a plugin's, e.g. Agreements).
# Contact is that slice of users (its default scope), so Contact, contact_id and the contact tools
# read as before. Archiving a contact deactivates the user.
class Contact < User
  include Searchable, PortalScope

  default_scope { where(role: User::CLIENT) }

  # Stored as "Contact" where a record is named by type (search, events), so it loads back as a
  # Contact, not a plain User (Rails would name it by its base class).
  def self.polymorphic_name = "Contact"

  belongs_to :client
  has_many :portal_sessions, class_name: "Session", foreign_key: :user_id, inverse_of: false, dependent: :destroy
  has_many :tasks, foreign_key: :contact_id, inverse_of: :contact, dependent: :nullify

  # What was a contact's email and archived_at, now the user's address and deactivation.
  alias_attribute :email, :email_address
  alias_attribute :archived_at, :deactivated_at

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase.presence }
  validates :email_address, presence: { message: "is needed for portal access" }, if: :portal_access?

  # Portal sign-in is a signed link, never a password: a contact gets one nobody knows. It works
  # once (signing in moves link_signed_in_at), for an hour.
  generates_token_for(:portal_login, expires_in: 1.hour) { link_signed_in_at }
  # The link in an invitation (invite_to_portal!): the same, good for a week.
  generates_token_for(:portal_invite, expires_in: 7.days) { link_signed_in_at }
  # A portal session nobody has used in this long is over (Portal::BaseController, pruned nightly).
  PORTAL_SESSION_IDLE = 90.days
  before_validation(on: :create) { self.password = SecureRandom.base58(32) if password_digest.blank? }

  scope :with_portal_access, -> { active.where(portal_access: true) }

  # Losing portal access, or being archived, signs them out of the portal at once.
  after_update_commit :end_portal_sessions, if: -> { !portal? && portal_sessions.exists? }

  def archive! = update!(deactivated_at: Time.current)
  def archived? = deactivated_at.present?

  # May sign in to the client portal now.
  def portal? = portal_access? && !archived? && email_address.present?

  # Whoever a sign-in or invitation link was made for, while it's good and they may still sign in.
  def self.from_portal_link(token)
    (find_by_token_for(:portal_login, token) || find_by_token_for(:portal_invite, token))&.then { it if it.portal? }
  end

  # Emails them the way in: what the portal is and a link that signs them in, good for a week.
  def invite_to_portal!
    PortalMailer.with(contact: self).invitation.deliver_later
    record_event!("contact.invited")
  end

  # Every browser they're signed in to the portal with, signed out (staff, from their page).
  def sign_out_of_portal!
    count = portal_sessions.count
    portal_sessions.destroy_all
    record_event!("contact.signed_out", payload: { sessions: count })
  end

  # A contact shows as a circle of initials.
  def initials = name.scan(/\b\p{L}/).first(2).join.upcase

  def search_title = name
  def search_content = [ title, email_address, phone ].compact_blank.join(" ")
  def search_client_id = client_id

  private
    def end_portal_sessions = portal_sessions.destroy_all
end
