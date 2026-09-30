class CreateMentionsAndNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :mentions do |t|
      t.references :source, polymorphic: true, null: false
      t.references :mentioner, null: false, foreign_key: { to_table: :users }
      t.references :mentionee, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :mentions, [ :source_type, :source_id, :mentionee_id ], unique: true

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :source, polymorphic: true, null: false
      t.datetime :read_at
      t.integer :unread_count, null: false, default: 0
      t.timestamps
    end
    add_index :notifications, [ :user_id, :read_at, :updated_at ]
  end
end
