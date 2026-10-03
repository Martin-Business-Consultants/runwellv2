# Which service brings requests' mail in, and its password, kept on the install (Settings > Email,
# or a plugin that sets it up) rather than only in the server's environment, which still wins.
class AddInboundEmailToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :inbound_ingress, :string
    add_column :settings, :inbound_password, :text
  end
end
