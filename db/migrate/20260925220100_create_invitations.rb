class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :email_address, null: false
      t.string :role, null: false, default: "member"
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.references :user, foreign_key: true
      t.datetime :sent_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :invitations, :email_address
  end
end
