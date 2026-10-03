class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints do |t|
      t.string :url, null: false
      t.string :description
      t.string :secret, null: false
      t.json :kinds
      t.boolean :include_security, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :failures_in_a_row, null: false, default: 0
      t.datetime :last_delivered_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.references :event, foreign_key: true
      t.string :kind, null: false
      t.integer :attempts, null: false, default: 0
      t.integer :status_code
      t.string :error
      t.integer :duration_ms
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :webhook_deliveries, %i[webhook_endpoint_id created_at]
  end
end
