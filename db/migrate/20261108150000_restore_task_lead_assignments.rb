# 6.0's rename (20261108090000) renamed columns on tasks, which SQLite does by copying the table and
# dropping the old one; foreign keys can't be switched off inside a migration's transaction, so the
# drop cascaded and deleted every assignment. "Mine" and the owner filter read assignments, so they
# showed nothing. Each task's lead is still tasks.owner_id: this puts its assignment back. Anyone
# else who was on a task is only in the backup taken before that update.
class RestoreTaskLeadAssignments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO assignments (task_id, user_id, created_at, updated_at)
      SELECT tasks.id, tasks.owner_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM tasks
      WHERE tasks.owner_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM assignments WHERE assignments.task_id = tasks.id AND assignments.user_id = tasks.owner_id)
    SQL
  end

  def down
  end
end
