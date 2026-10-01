# The agency itself as a client: its engagements are internal projects, with no agreement to
# send, price or approval.
class AddInternalToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :internal, :boolean, default: false, null: false
  end
end
