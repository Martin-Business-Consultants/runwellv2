# Account management, as a plugin. A lead is the person who answers for a client. Meetings hold
# the agenda sent before and the recap sent after, each timestamped when it went out; their action
# items are core commitments, linked here. Accesses are the register of a client's outside
# accounts (pages, ad accounts, pixels, domains): who owns each, what access we hold, where its
# login lives (never the secret itself), when its token expires and when someone last checked.
# Weekly updates are a lead's written Friday report, final once sent.
class CreateAccountManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :account_management_leads do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :account_management_meetings do |t|
      t.references :client, null: false, foreign_key: true
      t.references :engagement, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.text :agenda
      t.datetime :agenda_sent_at
      t.string :agenda_sent_via
      t.text :recap
      t.datetime :recap_sent_at
      t.string :recap_sent_via
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :account_management_meetings, :starts_at

    create_table :account_management_meeting_items do |t|
      t.references :meeting, null: false, foreign_key: { to_table: :account_management_meetings }
      t.references :commitment, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end

    create_table :account_management_accesses do |t|
      t.references :client, null: false, foreign_key: true
      t.references :verified_by, foreign_key: { to_table: :users }
      t.string :platform, null: false
      t.string :name, null: false
      t.string :external_id
      t.string :url
      t.string :owned_by, null: false, default: "unknown"
      t.string :owner_name
      t.string :our_access, null: false, default: "none"
      t.string :login_location
      t.date :token_expires_on
      t.date :verified_on
      t.text :notes
      t.timestamps
    end

    create_table :account_management_weekly_updates do |t|
      t.references :user, null: false, foreign_key: true
      t.date :week_of, null: false
      t.text :body
      t.datetime :sent_at
      t.timestamps
    end
    add_index :account_management_weekly_updates, [ :user_id, :week_of ], unique: true
  end
end
