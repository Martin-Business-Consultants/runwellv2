# QA, as a plugin. A check is one thing we're accountable for on a client (an email, a page, a
# webhook, a form), holding the expected values that are its source of truth. A run is one
# test of it, by a person, an agent, the nightly page fetch or the site's own report, and its
# results say, per expectation, what was seen. Runs and results are never changed. Issues are
# the defects found, with a fix (and its root cause) and a verification. Gates tie a check to
# a piece of work that can't be marked done until the check passes again.
class CreateQa < ActiveRecord::Migration[8.1]
  def change
    create_table :qa_checks do |t|
      t.references :client, null: false, foreign_key: true
      t.references :engagement, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :kind, null: false, default: "other"
      t.string :url
      t.boolean :live, null: false, default: false
      t.integer :every_days, null: false, default: 7
      t.text :instructions
      t.string :report_token, null: false
      t.datetime :retest_after
      t.datetime :archived_at
      t.timestamps
    end
    add_index :qa_checks, :report_token, unique: true

    create_table :qa_expectations do |t|
      t.references :check, null: false, foreign_key: { to_table: :qa_checks }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.string :key, null: false
      t.string :label, null: false
      t.text :expected
      t.string :match, null: false, default: "is"
      t.string :note
      t.date :expires_on
      t.integer :position, null: false, default: 0
      t.datetime :approved_at
      t.timestamps
    end
    add_index :qa_expectations, [ :check_id, :key ], unique: true

    create_table :qa_runs do |t|
      t.references :check, null: false, foreign_key: { to_table: :qa_checks }
      t.references :user, foreign_key: true
      t.string :source, null: false
      t.string :reporter
      t.string :status, null: false
      t.text :notes
      t.string :evidence_url
      t.integer :http_status
      t.timestamps
    end
    add_index :qa_runs, [ :check_id, :created_at ]

    create_table :qa_results do |t|
      t.references :run, null: false, foreign_key: { to_table: :qa_runs }
      t.references :expectation, foreign_key: { to_table: :qa_expectations, on_delete: :nullify }
      t.string :key, null: false
      t.string :label, null: false
      t.text :expected
      t.text :actual
      t.boolean :passed, null: false
      t.timestamps
    end

    create_table :qa_issues do |t|
      t.references :client, null: false, foreign_key: true
      t.references :engagement, foreign_key: true
      t.references :todo, foreign_key: true
      t.references :check, foreign_key: { to_table: :qa_checks }
      t.references :expectation, foreign_key: { to_table: :qa_expectations, on_delete: :nullify }
      t.references :run, foreign_key: { to_table: :qa_runs }
      t.references :opened_by, foreign_key: { to_table: :users }
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :fixed_by, foreign_key: { to_table: :users }
      t.references :verified_by, foreign_key: { to_table: :users }
      t.references :verified_by_run, foreign_key: { to_table: :qa_runs }
      t.string :title, null: false
      t.string :url
      t.text :steps
      t.text :expected
      t.text :actual
      t.string :environment
      t.boolean :found_live, null: false, default: false
      t.string :source, null: false, default: "app"
      t.string :root_cause
      t.text :fix_note
      t.datetime :fixed_at
      t.datetime :verified_at
      t.timestamps
    end

    create_table :qa_gates do |t|
      t.references :todo, null: false, foreign_key: true
      t.references :check, null: false, foreign_key: { to_table: :qa_checks }
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :qa_gates, [ :todo_id, :check_id ], unique: true
  end
end
