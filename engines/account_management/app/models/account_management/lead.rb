module AccountManagement
  # The one person who answers for a client: its meetings, its commitments, its accesses and
  # its line in their weekly update.
  class Lead < ::ApplicationRecord
    belongs_to :client, class_name: "::Client"
    belongs_to :user, class_name: "::User"

    validates :client_id, uniqueness: true

    # The clients a person leads.
    def self.clients_for(user) = ::Client.where(id: where(user: user).select(:client_id))
  end
end
