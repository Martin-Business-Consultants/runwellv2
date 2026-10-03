# A person's account with a sign-in provider (SignInProvider), connected from Settings > Your
# account or matched on first use by an address the provider has verified.
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, inclusion: { in: SignInProvider::PROVIDERS.keys }
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def provider_name = SignInProvider.name_for(provider)

  # Who an OmniAuth answer signs in: the person who connected that account, else an active
  # person whose address the provider vouches for (Google's email_verified, GitHub's verified
  # primary address; Microsoft's isn't vouched for, so it must be connected first).
  def self.user_for(auth)
    if (identity = find_by(provider: auth.provider, uid: auth.uid.to_s))
      identity.touch(:last_used_at)
      return identity.user if identity.user.active?
      return
    end

    email = verified_email(auth)
    user = email && User.people.active.find_by(email_address: email.downcase)
    user&.identities&.create!(provider: auth.provider, uid: auth.uid.to_s, email: email, last_used_at: Time.current)
    user
  end

  def self.verified_email(auth)
    case auth.provider
    when "google_oauth2" then auth.info.email if auth.extra&.raw_info&.email_verified.to_s == "true"
    when "github" then auth.info.email # omniauth-github gives only a verified primary address
    end
  end
end
