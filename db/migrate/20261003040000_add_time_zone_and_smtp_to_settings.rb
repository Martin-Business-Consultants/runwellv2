# Settled in the app rather than only the server's environment (which still wins where set): the
# agency's time zone, and the outgoing mail server, its password encrypted.
class AddTimeZoneAndSmtpToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :time_zone, :string
    add_column :settings, :smtp_address, :string
    add_column :settings, :smtp_port, :integer
    add_column :settings, :smtp_username, :string
    add_column :settings, :smtp_password, :text
    add_column :settings, :smtp_security, :string, default: "starttls", null: false
  end
end
