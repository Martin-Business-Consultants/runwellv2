# Each person's own plugin links in the nav: their order and which are hidden. Blank: every plugin
# that's on, in the order they registered, as before.
class AddNavPluginsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nav_plugins, :json
  end
end
