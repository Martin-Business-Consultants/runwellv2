# Someone at a client: a user with the client role (User::Role::CLIENT), so the team and the
# people they work for are one kind of person, listed together in Users. A contact never signs in
# to the staff app and has no permissions; with portal_access they sign in to the client portal by
# emailed link, and can_approve lets them say yes for their company (a plugin's, e.g. Agreements).
# Contact is that slice of users (its default scope), so Contact, contact_id and the contact tools
# read as before. Archiving a contact deactivates the user.
class Contact < User
  include Searchable

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

  # Portal sign-in is a signed link, never a password: a contact gets one nobody knows.
  generates_token_for :portal_login, expires_in: 1.hour
  before_validation(on: :create) { self.password = SecureRandom.base58(32) if password_digest.blank? }

  scope :with_portal_access, -> { active.where(portal_access: true) }

  # Losing portal access, or being archived, signs them out of the portal at once.
  after_update_commit :end_portal_sessions, if: -> { !portal? && portal_sessions.exists? }

  def archive! = update!(deactivated_at: Time.current)
  def archived? = deactivated_at.present?

  # May sign in to the client portal now.
  def portal? = portal_access? && !archived? && email_address.present?

  # A contact shows as a circle of initials, in one of the staff avatars' colours (avatars.css),
  # picked from the id so it stays the same everywhere.
  def initials = name.scan(/\b\p{L}/).first(2).join.upcase
  def avatar_tone = Zlib.crc32(id.to_s) % User::Avatar::AVATAR_COLORS.size + 1

  def search_title = name
  def search_content = [ title, email_address, phone ].compact_blank.join(" ")
  def search_client_id = client_id

  private
    def end_portal_sessions = portal_sessions.destroy_all
end
