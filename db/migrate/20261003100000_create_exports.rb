class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :state, null: false, default: "queued"
      t.integer :tables_count
      t.integer :rows_count
      t.integer :files_count
      t.string :error
      t.datetime :completed_at
      t.timestamps
    end
  end
end
