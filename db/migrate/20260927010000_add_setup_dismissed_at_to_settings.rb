class AddSetupDismissedAtToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :setup_dismissed_at, :datetime
  end
end
