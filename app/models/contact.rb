class Contact < ApplicationRecord
  include Searchable

  belongs_to :client
  has_many :portal_sessions, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :approvals, dependent: :nullify
  has_many :approval_links, dependent: :destroy
  has_many :requests, dependent: :nullify

  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :email, presence: { message: "is needed for portal access" }, if: :portal_access?

  # Portal sign-in is a signed link, never a password.
  generates_token_for :portal_login, expires_in: 1.hour

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:name) }
  scope :with_portal_access, -> { active.where(portal_access: true) }

  # Losing portal access, or being archived, signs them out of the portal at once.
  after_update_commit :end_portal_sessions, if: -> { !portal? && portal_sessions.exists? }

  def archive! = update!(archived_at: Time.current)
  def archived? = archived_at.present?

  # May sign in to the client portal now.
  def portal? = portal_access? && !archived? && email.present?

  # A contact shows as a circle of initials, in one of the staff avatars' colours (avatars.css),
  # picked from the id so it stays the same everywhere.
  def initials = name.scan(/\b\p{L}/).first(2).join.upcase
  def avatar_tone = Zlib.crc32(id.to_s) % User::Avatar::AVATAR_COLORS.size + 1

  def search_title = name
  def search_content = [ role, email, phone ].compact_blank.join(" ")

  private
    def end_portal_sessions = portal_sessions.destroy_all
end
