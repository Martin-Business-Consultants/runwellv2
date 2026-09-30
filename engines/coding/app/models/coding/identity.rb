module Coding
  # A person's GitHub login, so commits, reviews and repo access can be matched to them.
  class Identity < ::ApplicationRecord
    self.table_name = "coding_identities"

    belongs_to :user, class_name: "::User"

    normalizes :github_login, with: ->(value) { value.to_s.strip.delete_prefix("@").downcase.presence }

    validates :github_login, presence: true, uniqueness: { message: "belongs to someone else here" },
      format: { with: /\A[a-z\d](?:[a-z\d-]{0,38})\z/, message: "isn’t a GitHub username" }

    def self.user_for(login) = login.present? ? find_by(github_login: login.to_s.downcase)&.user : nil

    # Sets or (blank) removes someone's login; the flash to redirect with.
    def self.assign(user, login)
      identity = find_or_initialize_by(user: user)
      if login.to_s.strip.blank?
        identity.destroy if identity.persisted?
        { notice: "Removed #{user.display_name}’s GitHub username." }
      elsif identity.update(github_login: login)
        { notice: "#{user.display_name} is @#{identity.github_login} on GitHub." }
      else
        { alert: identity.errors.full_messages.to_sentence }
      end
    end
  end
end
