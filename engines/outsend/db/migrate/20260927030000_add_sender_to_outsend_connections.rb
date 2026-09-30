# Who mail sent through Outsend comes from: a name and an address (on a domain Outsend lets you
# send from). Blank keeps the install's default sender (MAIL_FROM).
class AddSenderToOutsendConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :outsend_connections, :from_name, :string
    add_column :outsend_connections, :from_email, :string
  end
end
