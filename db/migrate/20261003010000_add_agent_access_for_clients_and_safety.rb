# Bots for staff and clients alike: a token (and an OAuth grant) may belong to a client's contact
# instead of a person on staff; tokens can be paused; every agent call is logged, and a write sent
# again with the same idempotency key answers as before instead of running twice. The agency
# decides whether a client's agent may approve agreements.
class AddAgentAccessForClientsAndSafety < ActiveRecord::Migration[8.1]
  def change
    change_column_null :access_tokens, :user_id, true
    add_reference :access_tokens, :contact, foreign_key: true
    add_column :access_tokens, :paused_at, :datetime

    change_column_null :oauth_grants, :user_id, true
    add_reference :oauth_grants, :contact, foreign_key: true

    create_table :agent_calls do |t|
      t.references :access_token, null: false, foreign_key: true
      t.string :tool, null: false
      t.string :status, null: false
      t.string :code
      t.string :summary
      t.integer :duration_ms
      t.datetime :created_at, null: false
      t.index [ :access_token_id, :created_at ]
    end

    create_table :agent_idempotency_keys do |t|
      t.references :access_token, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :tool, null: false
      t.json :response, null: false, default: {}
      t.datetime :created_at, null: false
      t.index [ :access_token_id, :key ], unique: true
      t.index :created_at
    end

    add_column :settings, :client_agent_approvals, :boolean, default: true, null: false
  end
end
