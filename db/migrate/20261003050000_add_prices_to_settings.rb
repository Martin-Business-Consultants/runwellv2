# Whether agreements carry prices at all (Settings > Names): off for an install that plans without
# money (a home, a wedding, internal work), on by default.
class AddPricesToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :prices, :boolean, default: true, null: false
  end
end
