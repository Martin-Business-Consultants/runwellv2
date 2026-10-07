# Everyone on a piece of work (Fizzy's assignments). todos.owner_id stays as the lead, so every
# owner so far becomes an assignment here.
class CreateAssignments < ActiveRecord::Migration[8.1]
  def up
    create_table :assignments do |t|
      t.references :todo, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.references :assigner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :assignments, %i[todo_id user_id], unique: true

    execute <<~SQL
      INSERT INTO assignments (todo_id, user_id, created_at, updated_at)
      SELECT id, owner_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM todos WHERE owner_id IS NOT NULL
    SQL
  end

  def down
    drop_table :assignments
  end
end
