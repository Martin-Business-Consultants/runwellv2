# The Factory, as a plugin. An item is a todo handed to agents (one per todo), with any extra
# instructions. A run is one attempt by a runner: claimed with a lease the runner keeps alive,
# finished with a summary, branch, pull request and cost. Settings are one row: how many runs
# at once, how long a lease and a run may last, how many attempts, the monthly budget, whether
# approval queues work by itself, and which clients never get agent work.
class CreateFactory < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_settings do |t|
      t.integer :max_concurrent_runs, null: false, default: 2
      t.integer :lease_minutes, null: false, default: 10
      t.integer :run_time_limit_minutes, null: false, default: 60
      t.integer :max_attempts, null: false, default: 2
      t.integer :monthly_budget_cents
      t.boolean :queue_on_approval, null: false, default: false
      t.json :blocked_client_ids, null: false, default: []
      t.timestamps
    end

    create_table :factory_items do |t|
      t.references :todo, null: false, foreign_key: true, index: { unique: true }
      t.references :engagement, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :queued_by, foreign_key: { to_table: :users }
      t.text :instructions
      t.string :source, null: false, default: "app"
      t.datetime :queued_at, null: false
      t.timestamps
    end

    create_table :factory_runs do |t|
      t.references :item, foreign_key: { to_table: :factory_items, on_delete: :nullify }
      t.references :todo, null: false, foreign_key: true
      t.references :claimed_by, foreign_key: { to_table: :users }
      t.string :runner, null: false
      t.string :status, null: false, default: "running"
      t.integer :attempt, null: false, default: 1
      t.datetime :started_at, null: false
      t.datetime :lease_expires_at, null: false
      t.datetime :heartbeat_at
      t.datetime :finished_at
      t.string :branch
      t.string :pull_request_url
      t.string :log_url
      t.text :summary
      t.text :error
      t.integer :cost_cents, null: false, default: 0
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.timestamps
    end
    add_index :factory_runs, :status
    add_index :factory_runs, :item_id, unique: true, where: "status = 'running'", name: "index_factory_runs_one_running_per_item"
  end
end
