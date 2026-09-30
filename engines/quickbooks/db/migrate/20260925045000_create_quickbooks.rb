# QuickBooks, as a plugin. The connection is the agency's own Intuit app and the company it
# signed in to (one row). A client is linked to a QuickBooks customer by id, never by name. A
# service is linked to a recurring invoice template, kept in step with what the client
# approved. Invoices and payments mirror what QuickBooks holds for linked customers; a billing
# plan remembers a work order's deposit and whether to send the balance when it closes.
class CreateQuickbooks < ActiveRecord::Migration[8.1]
  def change
    create_table :quickbooks_connections do |t|
      t.string :client_id
      t.text :client_secret
      t.string :environment, null: false, default: "production"
      t.string :realm_id
      t.string :company_name
      t.text :access_token
      t.text :refresh_token
      t.datetime :access_expires_at
      t.datetime :refresh_expires_at
      t.string :oauth_state
      t.datetime :connected_at
      t.string :default_item_id
      t.string :default_item_name
      t.datetime :last_synced_at
      t.text :last_error
      t.json :last_sync_summary
      t.timestamps
    end

    create_table :quickbooks_customers do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.string :qbo_id, null: false
      t.string :display_name
      t.string :email
      t.timestamps
    end
    add_index :quickbooks_customers, :qbo_id, unique: true

    create_table :quickbooks_recurring_links do |t|
      t.references :engagement, null: false, foreign_key: true, index: { unique: true }
      t.references :contact, foreign_key: true
      t.string :qbo_id, null: false
      t.string :sync_token
      t.string :name
      t.integer :amount_cents
      t.string :interval_type
      t.integer :num_interval
      t.boolean :active, null: false, default: true
      t.date :next_on
      t.string :drift
      t.datetime :pushed_at
      t.datetime :synced_at
      t.timestamps
    end

    create_table :quickbooks_invoices do |t|
      t.string :qbo_id, null: false
      t.references :client, null: false, foreign_key: true
      t.references :engagement, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :kind, null: false, default: "other"
      t.string :doc_number
      t.date :txn_date
      t.date :due_on
      t.integer :total_cents, null: false, default: 0
      t.integer :balance_cents, null: false, default: 0
      t.boolean :voided, null: false, default: false
      t.text :payment_link
      t.string :sent_to
      t.datetime :sent_at
      t.string :sync_token
      t.datetime :synced_at
      t.timestamps
    end
    add_index :quickbooks_invoices, :qbo_id, unique: true

    create_table :quickbooks_payments do |t|
      t.string :qbo_id, null: false
      t.references :invoice, null: false, foreign_key: { to_table: :quickbooks_invoices }
      t.integer :amount_cents, null: false
      t.date :paid_on, null: false
      t.string :method_name
      t.timestamps
    end
    add_index :quickbooks_payments, :qbo_id, unique: true

    create_table :quickbooks_billing_plans do |t|
      t.references :engagement, null: false, foreign_key: true, index: { unique: true }
      t.references :contact, foreign_key: true
      t.references :deposit_invoice, foreign_key: { to_table: :quickbooks_invoices }
      t.references :balance_invoice, foreign_key: { to_table: :quickbooks_invoices }
      t.boolean :send_balance_on_close, null: false, default: false
      t.text :last_error
      t.timestamps
    end
  end
end
