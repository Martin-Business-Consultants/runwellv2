class User < ApplicationRecord
  include Named, Avatar, Mentionable, Role, Agent, TwoFactor, Access, Eventful, NavPlugins, TextFilterable

  filters_text_on "users.name", "users.email_address", "users.title"

  has_secure_password

  # An emailed sign-in link (Sessions::LinksController): good for 15 minutes, and once, since
  # signing in with it moves link_signed_in_at.
  generates_token_for(:link_sign_in, expires_in: 15.minutes) { link_signed_in_at }
  has_many :sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :delete_all
  # Someone at a client (the client role, Contact) belongs to it.
  belongs_to :client, optional: true
  has_many :tasks, foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :notifications, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  # Staff sign in with their address; a client's contact (Contact) may have only a phone.
  validates :email_address, presence: true, unless: :client?
  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  before_validation :become_owner, on: :create, if: -> { !client? && User.none? }
  after_update :record_role_change, if: :saved_change_to_role?

  def display_name = name.presence || email_address

  # An owner as filters and forms name one: "me" (the person acting), "none" or blank (nobody, nil),
  # or a person's id or name (::Agent::Resolver, which raises when a name matches no one or several).
  def self.owner_id_for(value, me:)
    case value.to_s
    when "", "none" then nil
    when "me" then me.id
    else ::Agent::Resolver.id_for("User", value)
    end
  end

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
