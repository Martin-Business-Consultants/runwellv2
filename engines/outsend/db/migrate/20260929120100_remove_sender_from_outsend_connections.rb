# The sender moved to the install's settings (Settings > Email), which already holds a copy of
# any sender saved here; Outsend now sends as whoever that is.
class RemoveSenderFromOutsendConnections < ActiveRecord::Migration[8.1]
  def change
    remove_column :outsend_connections, :from_name, :string
    remove_column :outsend_connections, :from_email, :string
  end
end
