# Plugins installed on the server from Settings > Plugins: each install, update or removal
# someone started, with how it went, and the newest release of each installed plugin.
class CreatePluginChanges < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :plugin_releases, :json, default: {}, null: false

    create_table :plugin_changes do |t|
      t.references :requested_by, foreign_key: { to_table: :users }
      t.string :key
      t.string :repo, null: false
      t.string :action, null: false
      t.string :from_version
      t.string :to_version
      t.string :status, null: false, default: "running"
      t.text :message
      t.datetime :finished_at
      t.timestamps
    end
    add_index :plugin_changes, :status
  end
end
