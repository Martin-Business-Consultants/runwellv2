# A session, token or OAuth grant belongs to one person (user_id): someone on staff (user) or
# someone at a client (contact, a user with the client role). The two associations read the same
# column and each finds only its own kind, so a client's session or token never reaches a staff
# surface (which reads user) and a staff one never reaches the portal (which reads contact).
module HeldByPerson
  extend ActiveSupport::Concern

  included do
    belongs_to :user, -> { where.not(role: User::CLIENT) }, optional: true, inverse_of: false
    belongs_to :contact, foreign_key: :user_id, optional: true, inverse_of: false
  end

  class_methods do
    # Who holds it, as create! takes it: whichever of the two was given (both would overwrite).
    def holder(user: nil, contact: nil) = user ? { user: user } : { contact: contact }
  end
end
