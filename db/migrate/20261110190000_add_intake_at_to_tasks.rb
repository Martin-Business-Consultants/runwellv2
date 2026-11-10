# Intake becomes a decision: a task is in it from when it came in without an owner or a piece of
# work (intake_at) until someone accepts or declines it. Tasks waiting now keep their place.
class AddIntakeAtToTasks < ActiveRecord::Migration[8.1]
  def up
    add_column :tasks, :intake_at, :datetime
    add_index :tasks, :intake_at
    execute <<~SQL
      UPDATE tasks SET intake_at = created_at
      WHERE status != 'done' AND accepted_at IS NULL AND declined_at IS NULL AND (owner_id IS NULL OR work_id IS NULL)
    SQL
  end

  def down
    remove_index :tasks, :intake_at
    remove_column :tasks, :intake_at
  end
end
