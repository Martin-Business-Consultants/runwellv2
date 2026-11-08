# A browser signed in: to the staff app (user, by password, link or two-factor) or to the client
# portal (contact, by emailed link; its own cookie, Portal::BaseController).
class Session < ApplicationRecord
  include HeldByPerson
end
