# Another Runwell install a person also works in (WorkspaceLink), shown on the workspace rail.
class CreateWorkspaceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :name
      t.string :icon_url
      t.string :color
      t.integer :position, null: false, default: 0
      t.text :remote_key
      t.string :key_digest
      t.string :nonce_digest
      t.datetime :nonce_expires_at
      t.datetime :linked_at
      t.integer :unread_count
      t.integer :intake_count
      t.datetime :badges_at
      t.timestamps
    end
    add_index :workspace_links, :key_digest, unique: true
    add_index :workspace_links, :nonce_digest, unique: true
    add_index :workspace_links, %i[user_id url], unique: true
  end
end
