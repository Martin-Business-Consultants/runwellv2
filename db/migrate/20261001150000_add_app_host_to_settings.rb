# Where this install is reached, for links made outside a request (mail): the address an owner
# set in Settings > Address, and the one people were last seen using, for when neither that nor
# APP_HOST is set.
class AddAppHostToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :app_host, :string
    add_column :settings, :app_protocol, :string
    add_column :settings, :seen_host, :string
  end
end
