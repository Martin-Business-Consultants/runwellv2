# Updates through KamalCloud (Upgrade::Hoster): a token from the KamalCloud install this runs on,
# kept encrypted, so an update can move the app's image tag and deploy it with no downtime.
class AddHosterTokenToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :hoster_token, :string
  end
end
