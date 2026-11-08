# A task's discussion with the client: notes either side shares (the portal shows them on the
# task; staff send one with "Send to client"). Off for every note so far, which stay internal.
class AddClientVisibleToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :client_visible, :boolean, default: false, null: false
  end
end
