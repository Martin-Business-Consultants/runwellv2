# Removals waiting out their Undo window (PendingRemoval): a task removed in the browser stays until
# its removal comes due, eight seconds on, unless someone undoes it first. A new table, so it's safe
# on a live install.
class CreatePendingRemovals < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_removals do |t|
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :batch, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :pending_removals, %i[record_type record_id], unique: true
    add_index :pending_removals, :batch
    add_index :pending_removals, :created_at
  end
end
