class User < ApplicationRecord
  include Named, Avatar, Mentionable, Role, Agent

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :todos, foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :questions, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :become_owner, on: :create, if: -> { User.none? }

  def display_name = name.presence || email_address

  private

  # The first person to sign up runs the agency.
  def become_owner
    self.role = "owner"
  end

  ActiveSupport.run_load_hooks(:runwell_user, self)
end
