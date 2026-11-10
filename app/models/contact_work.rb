# A piece of work a limited contact sees in the portal (Contact::PortalScope).
class ContactWork < ApplicationRecord
  belongs_to :contact, foreign_key: :user_id, inverse_of: :contact_works
  belongs_to :work
end
