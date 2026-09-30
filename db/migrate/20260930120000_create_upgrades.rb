# Updating the install from Settings > Updates: the newest release GitHub lists, kept on the one
# settings row, and each update someone started, with how it went.
class CreateUpgrades < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :latest_release, :json, default: {}, null: false
    add_column :settings, :release_checked_at, :datetime

    create_table :upgrades do |t|
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :from_version, null: false
      t.string :to_version, null: false
      t.string :via, null: false
      t.string :status, null: false, default: "running"
      t.string :external_id
      t.string :external_url
      t.text :message
      t.datetime :finished_at
      t.timestamps
    end
    add_index :upgrades, :status
  end
end
