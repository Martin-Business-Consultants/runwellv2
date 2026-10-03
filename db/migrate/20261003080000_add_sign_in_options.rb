class AddSignInOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_providers do |t|
      t.string :key, null: false
      t.string :client_id
      t.string :client_secret
      t.string :tenant_id
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end
    add_index :sign_in_providers, :key, unique: true

    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :identities, %i[provider uid], unique: true

    add_column :users, :passwordless, :boolean, null: false, default: false
    add_column :users, :link_signed_in_at, :datetime
  end
end
