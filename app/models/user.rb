class User < ApplicationRecord
  include Named, Avatar, Mentionable, Role, Agent, TwoFactor, Eventful

  has_secure_password

  # An emailed sign-in link (Sessions::LinksController): good for 15 minutes, and once, since
  # signing in with it moves link_signed_in_at.
  generates_token_for(:link_sign_in, expires_in: 15.minutes) { link_signed_in_at }
  has_many :sessions, dependent: :destroy
  has_many :todos, foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :questions, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :ai_suggestions, dependent: :destroy
  has_many :ai_chats, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :become_owner, on: :create, if: -> { User.none? }
  after_update :record_role_change, if: :saved_change_to_role?

  def display_name = name.presence || email_address

  private

  # Settings > Audit log: who changed whose role.
  def record_role_change
    from, to = saved_change_to_role
    record_event!("user.role_changed", payload: { from: from, to: to }) if from
  end

  # The first person to sign up owns the install.
  def become_owner
    self.role = "owner"
  end

  ActiveSupport.run_load_hooks(:runwell_user, self)
end
