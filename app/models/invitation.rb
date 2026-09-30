# How people join after the first owner: the owner invites an email address with a role, and
# the emailed link (signed, expiring, good once) lets them choose a name and password.
class Invitation < ApplicationRecord
  EXPIRES_IN = 7.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :user, optional: true

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email_address, uniqueness: { conditions: -> { pending }, message: "already has an invitation" }, on: :create
  validates :role, inclusion: { in: User::ROLES }
  validate :not_on_the_team, on: :create

  before_validation { self.sent_at ||= Time.current }

  scope :pending, -> { where(accepted_at: nil) }
  scope :ordered, -> { order(sent_at: :desc) }

  generates_token_for :acceptance, expires_in: EXPIRES_IN do
    [ sent_at.to_i, accepted_at ]
  end

  def self.find_by_token(token) = find_by_token_for(:acceptance, token)

  def expired? = sent_at < EXPIRES_IN.ago

  # A fresh link: the old one stops working.
  def resend!
    update!(sent_at: Time.current)
    deliver
  end

  def deliver = InvitationMailer.invite(self).deliver_later

  def accept!(name:, password:)
    transaction do
      person = User.create!(email_address: email_address, name: name, password: password, role: role)
      update!(accepted_at: Time.current, user: person)
      person
    end
  end

  private
    def not_on_the_team
      errors.add(:email_address, "is already on the team") if User.exists?(email_address: email_address)
    end
end
