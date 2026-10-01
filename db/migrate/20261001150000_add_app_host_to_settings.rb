# The address people use this install at, kept from their requests, for links in mail when
# APP_HOST isn't set.
class AddAppHostToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :app_host, :string
  end
end
