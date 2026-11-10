# Intake's two decisions on a task (Task::Intake): accepted (someone owns it, so it leaves Intake
# even before it's on a piece of work) and declined (kept, marked done, shown to the client as
# Declined). Who decided, for History and the side panel.
class AddIntakeDecisionsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :accepted_at, :datetime
    add_reference :tasks, :accepted_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
    add_column :tasks, :declined_at, :datetime
    add_reference :tasks, :declined_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
  end
end
