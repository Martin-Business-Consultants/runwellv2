# Notifications pushed to a person's browser or installed app (PushSubscription), signed with the
# install's own VAPID keys (Setting::Push; the private one encrypted). New table and columns only,
# so it's safe on a live install.
class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.string :user_agent
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true

    add_column :settings, :push_public_key, :string
    add_column :settings, :push_private_key, :string
  end
end
